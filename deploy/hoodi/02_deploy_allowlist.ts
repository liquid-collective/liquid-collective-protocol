import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers as EthersType } from "ethers";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

// Deploy the following contracts:
// 1. Allowlist (AllowlistV1 + TUPProxy + AllowlistFirewall + AllowlistProxyFirewall)
//
// IMPLEMENTATION NOTE (Option C):
// The proxy is deployed first with deployer as temporary admin (no execute/init).
// The Firewalls are then deployed with the actual proxy address (no nonce pre-computation).
// The proxy is initialized via upgradeToAndCall, then admin is transferred to
// AllowlistProxyFirewall. All steps are idempotent.

const implementationVersion = "1_2_1";

// EIP-1967 admin storage slot
const EIP1967_ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

const PROXY_ADMIN_ABI = [
  "function upgradeToAndCall(address newImplementation, bytes calldata data) external payable",
  "function changeAdmin(address newAdmin) external",
];

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  if (!["hardhat", "local", "tenderly", "hoodi"].includes(network.name)) {
    throw new Error("Invalid network for hoodi deployment");
  }
  const { deployer, proxyAdministrator, governor, executor } = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  const proxyArtifact = await deployments.getArtifact("TUPProxy");
  const proxyInterface = new ethers.utils.Interface(proxyArtifact.abi);

  const allowlistArtifact = await deployments.getArtifact("AllowlistV1");
  const allowlistInterface = new ethers.utils.Interface(allowlistArtifact.abi);

  // ============================================================
  // PHASE 1: Deploy the Allowlist proxy with deployer as temp admin.
  //          No execute — proxy is uninitialized at this stage.
  //          Actual proxy address is now known.
  // ============================================================

  const allowlistDeployment = await deployments.deploy("Allowlist", {
    contract: "AllowlistV1",
    from: deployer,
    log: true,
    proxy: {
      owner: deployer,
      proxyContract: "TUPProxy",
      implementationName: `AllowlistV1_Implementation_${implementationVersion}`,
    },
  });

  await verify("TUPProxy", allowlistDeployment.address, allowlistDeployment.args, allowlistDeployment.libraries);
  await verify("AllowlistV1", allowlistDeployment.implementation, []);

  // ============================================================
  // PHASE 2: Deploy Firewalls with the actual Allowlist proxy address.
  //          No nonce pre-computation needed.
  // ============================================================

  const firewallDeployment = await deployments.deploy("AllowlistFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, allowlistDeployment.address, []],
  });
  await verify("Firewall", firewallDeployment.address, firewallDeployment.args);

  const allowlistProxyFirewallDeployment = await deployments.deploy("AllowlistProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, allowlistDeployment.address, [proxyInterface.getSighash("pause()")]],
  });
  await verify("Firewall", allowlistProxyFirewallDeployment.address, allowlistProxyFirewallDeployment.args);

  // ============================================================
  // PHASE 3: Initialize the proxy via upgradeToAndCall (idempotent).
  //          Check getAllower() != address(0) to detect prior initialization.
  // ============================================================

  const allowerRaw = await ethers.provider.call({
    from: EthersType.constants.AddressZero,
    to: allowlistDeployment.address,
    data: allowlistInterface.encodeFunctionData("getAllower"),
  });
  const [currentAllower] = allowlistInterface.decodeFunctionResult("getAllower", allowerRaw);

  if (currentAllower === EthersType.constants.AddressZero) {
    console.log("  Initializing Allowlist...");
    const proxy = new EthersType.Contract(allowlistDeployment.address, PROXY_ADMIN_ABI, signer);
    const tx = await proxy.upgradeToAndCall(
      allowlistDeployment.implementation,
      allowlistInterface.encodeFunctionData("initAllowlistV1", [firewallDeployment.address, firewallDeployment.address])
    );
    await tx.wait();
    console.log(`  Allowlist initialized. tx: ${tx.hash}`);
  } else {
    console.log("  Allowlist already initialized, skipping.");
  }

  // ============================================================
  // PHASE 4: Transfer proxy admin to AllowlistProxyFirewall (idempotent).
  // ============================================================

  const adminSlotRaw = await ethers.provider.getStorageAt(allowlistDeployment.address, EIP1967_ADMIN_SLOT);
  const currentAdmin = EthersType.utils.getAddress("0x" + adminSlotRaw.slice(-40));

  if (currentAdmin.toLowerCase() !== allowlistProxyFirewallDeployment.address.toLowerCase()) {
    console.log(`  Transferring Allowlist proxy admin to AllowlistProxyFirewall...`);
    const proxy = new EthersType.Contract(allowlistDeployment.address, PROXY_ADMIN_ABI, signer);
    const tx = await proxy.changeAdmin(allowlistProxyFirewallDeployment.address);
    await tx.wait();
    console.log(`  Proxy admin transferred. tx: ${tx.hash}`);
  } else {
    console.log("  Allowlist proxy admin already set, skipping.");
  }

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  // Check proxy artifact exists AND that initialization completed (getAllower() != address(0)).
  if (!(await isDeployed("Allowlist", deployments, __filename))) return false;

  try {
    const allowlistDeployment = await deployments.get("Allowlist");
    const iface = new ethers.utils.Interface(["function getAllower() external view returns (address)"]);
    const result = await ethers.provider.call({
      from: ethers.constants.AddressZero,
      to: allowlistDeployment.address,
      data: iface.encodeFunctionData("getAllower"),
    });
    const [allower] = iface.decodeFunctionResult("getAllower", result);
    const shouldSkip = allower !== ethers.constants.AddressZero;
    if (shouldSkip) {
      console.log("Skipped");
      logStepEnd(__filename);
    }
    return shouldSkip;
  } catch (_error) {
    return false;
  }
};

func.tags = ["all", "allowlist"];

export default func;
