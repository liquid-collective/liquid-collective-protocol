import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers as EthersType } from "ethers";
import { logStep, logStepEnd } from "../../ts-utils/helpers/index";

const version = "1_3_0";

// EIP-1967 implementation storage slot
const EIP1967_IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

// Read the current implementation address from the EIP-1967 slot
async function getProxyImplementation(
  proxyAddress: string,
  provider: EthersType.providers.Provider
): Promise<string> {
  const raw = await provider.getStorageAt(proxyAddress, EIP1967_IMPL_SLOT);
  return EthersType.utils.getAddress("0x" + raw.slice(-40));
}

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  if (!["hardhat", "local", "tenderly", "hoodi", "devHoodi", "kurtosis"].includes(network.name)) {
    throw new Error("Invalid network for devHoodi deployment");
  }

  const { proxyAdministrator } = await getNamedAccounts();

  const proxyTransparentArtifact = await deployments.getArtifact("ITransparentUpgradeableProxy");
  const proxyTransparentInterface = new ethers.utils.Interface(proxyTransparentArtifact.abi);

  // On Tenderly virtual testnets, we impersonate proxyAdministrator and send
  // unsigned txs directly via the RPC (bypassing Hardhat's local signer).
  // On real networks, we use ethers.getSigner which signs locally with PRIVATE_KEY.
  const isVirtualTestnet = network.name === "tenderly";
  let signer: EthersType.Signer;

  if (isVirtualTestnet) {
    await network.provider.request({
      method: "tenderly_setBalance",
      params: [proxyAdministrator, "0x56BC75E2D63100000"], // 100 ETH
    });
    // Create a JsonRpcProvider that talks directly to the RPC, bypassing
    // Hardhat's LocalAccountsProvider which would reject unsigned sends.
    const directProvider = new EthersType.providers.JsonRpcProvider(
      (network.config as any).url
    );
    signer = directProvider.getSigner(proxyAdministrator);
  } else {
    signer = await ethers.getSigner(proxyAdministrator);
  }

  // Load proxy deployments
  const withdrawProxy = await deployments.get("Withdraw");
  const coverageFundProxy = await deployments.get("CoverageFund");
  const elFeeRecipientProxy = await deployments.get("ELFeeRecipient");
  const allowlistProxy = await deployments.get("Allowlist");
  const operatorsRegistryProxy = await deployments.get("OperatorsRegistry");
  const oracleProxy = await deployments.get("Oracle");
  const redeemManagerProxy = await deployments.get("RedeemManager");
  const riverProxy = await deployments.get("River");

  // Load new implementation deployments
  const withdrawImpl = await deployments.get(`WithdrawV1_Implementation_${version}`);
  const coverageFundImpl = await deployments.get(`CoverageFundV1_Implementation_${version}`);
  const elFeeRecipientImpl = await deployments.get(`ELFeeRecipientV1_Implementation_${version}`);
  const allowlistImpl = await deployments.get(`AllowlistV1_Implementation_${version}`);
  const operatorsRegistryImpl = await deployments.get(`OperatorsRegistryV1_Implementation_${version}`);
  const oracleImpl = await deployments.get(`OracleV1_Implementation_${version}`);
  const redeemManagerImpl = await deployments.get(`RedeemManagerV1_Implementation_${version}`);
  const riverImpl = await deployments.get(`RiverV1_Implementation_${version}`);

  // Load ProxyFirewall addresses (these are the admin for firewalled proxies)
  const riverProxyFirewall = await deployments.get("RiverProxyFirewall");
  const oracleProxyFirewall = await deployments.get("OracleProxyFirewall");
  const operatorsRegistryProxyFirewall = await deployments.get("OperatorsRegistryProxyFirewall");
  const redeemManagerProxyFirewall = await deployments.get("RedeemManagerProxyFirewall");
  const allowlistProxyFirewall = await deployments.get("AllowlistProxyFirewall");

  // Load AllowlistFirewall address (= denier for initAllowlistV1_1)
  const allowlistFirewall = await deployments.get("AllowlistFirewall");

  // ============================================================
  // Helper: upgrade a proxy via upgradeTo (no init call)
  // sendTo = proxy address for direct-admin proxies, or ProxyFirewall address for firewalled proxies
  // ============================================================
  async function doUpgradeTo(
    proxyAddress: string,
    sendTo: string,
    newImplAddress: string,
    label: string
  ): Promise<void> {
    const currentImpl = await getProxyImplementation(proxyAddress, ethers.provider);
    if (currentImpl.toLowerCase() === newImplAddress.toLowerCase()) {
      console.log(`  ${label}: already upgraded to ${newImplAddress}, skipping.`);
      return;
    }
    console.log(`  ${label}: upgrading from ${currentImpl} to ${newImplAddress}...`);
    const upgradeData = proxyTransparentInterface.encodeFunctionData("upgradeTo", [newImplAddress]);
    const tx = await signer.sendTransaction({ to: sendTo, data: upgradeData });
    await tx.wait();
    console.log(`  ${label}: upgraded. tx: ${tx.hash}`);
  }

  // ============================================================
  // Helper: upgrade a proxy via upgradeToAndCall (with init)
  // ============================================================
  async function doUpgradeToAndCall(
    proxyAddress: string,
    sendTo: string,
    newImplAddress: string,
    initData: string,
    label: string
  ): Promise<void> {
    const currentImpl = await getProxyImplementation(proxyAddress, ethers.provider);
    if (currentImpl.toLowerCase() === newImplAddress.toLowerCase()) {
      console.log(`  ${label}: already upgraded to ${newImplAddress}, skipping.`);
      return;
    }
    console.log(`  ${label}: upgrading from ${currentImpl} to ${newImplAddress} with init...`);
    const upgradeData = proxyTransparentInterface.encodeFunctionData("upgradeToAndCall", [
      newImplAddress,
      initData,
    ]);
    const tx = await signer.sendTransaction({ to: sendTo, data: upgradeData });
    await tx.wait();
    console.log(`  ${label}: upgraded and initialized. tx: ${tx.hash}`);
  }

  // ============================================================
  // PHASE 1: Simple upgrades (upgradeTo, no init)
  // Direct admin proxies: Withdraw, CoverageFund, ELFeeRecipient
  // ============================================================

  console.log("\n=== Phase 1: Simple upgrades (upgradeTo) ===\n");

  await doUpgradeTo(
    withdrawProxy.address,
    withdrawProxy.address, // direct admin
    withdrawImpl.address,
    "Withdraw"
  );

  await doUpgradeTo(
    coverageFundProxy.address,
    coverageFundProxy.address, // direct admin
    coverageFundImpl.address,
    "CoverageFund"
  );

  await doUpgradeTo(
    elFeeRecipientProxy.address,
    elFeeRecipientProxy.address, // direct admin
    elFeeRecipientImpl.address,
    "ELFeeRecipient"
  );

  // ============================================================
  // PHASE 2: Upgrades with initialization (upgradeToAndCall)
  // Firewalled proxies: send tx to ProxyFirewall address
  // ============================================================

  console.log("\n=== Phase 2: Upgrades with initialization (upgradeToAndCall) ===\n");

  // Allowlist: initAllowlistV1_1(denier) where denier = AllowlistFirewall address
  const allowlistArtifact = await deployments.getArtifact("AllowlistV1");
  const allowlistInterface = new ethers.utils.Interface(allowlistArtifact.abi);
  await doUpgradeToAndCall(
    allowlistProxy.address,
    allowlistProxyFirewall.address, // firewalled
    allowlistImpl.address,
    allowlistInterface.encodeFunctionData("initAllowlistV1_1", [allowlistFirewall.address]),
    "Allowlist"
  );

  // OperatorsRegistry: initOperatorsRegistryV1_1()
  const operatorsRegistryArtifact = await deployments.getArtifact("OperatorsRegistryV1");
  const operatorsRegistryInterface = new ethers.utils.Interface(operatorsRegistryArtifact.abi);
  await doUpgradeToAndCall(
    operatorsRegistryProxy.address,
    operatorsRegistryProxyFirewall.address, // firewalled
    operatorsRegistryImpl.address,
    operatorsRegistryInterface.encodeFunctionData("initOperatorsRegistryV1_1"),
    "OperatorsRegistry"
  );

  // Oracle: initOracleV1_1()
  const oracleArtifact = await deployments.getArtifact("OracleV1");
  const oracleInterface = new ethers.utils.Interface(oracleArtifact.abi);
  await doUpgradeToAndCall(
    oracleProxy.address,
    oracleProxyFirewall.address, // firewalled
    oracleImpl.address,
    oracleInterface.encodeFunctionData("initOracleV1_1"),
    "Oracle"
  );

  // RedeemManager: initializeRedeemManagerV1_2()
  const redeemManagerArtifact = await deployments.getArtifact("RedeemManagerV1");
  const redeemManagerInterface = new ethers.utils.Interface(redeemManagerArtifact.abi);
  await doUpgradeToAndCall(
    redeemManagerProxy.address,
    redeemManagerProxyFirewall.address, // firewalled
    redeemManagerImpl.address,
    redeemManagerInterface.encodeFunctionData("initializeRedeemManagerV1_2"),
    "RedeemManager"
  );

  // ============================================================
  // PHASE 3: River upgrade (last, depends on others being current)
  // ============================================================

  console.log("\n=== Phase 3: River upgrade (upgradeToAndCall) ===\n");

  // River: initRiverV1_2()
  const riverArtifact = await deployments.getArtifact("RiverV1");
  const riverInterface = new ethers.utils.Interface(riverArtifact.abi);
  await doUpgradeToAndCall(
    riverProxy.address,
    riverProxyFirewall.address, // firewalled
    riverImpl.address,
    riverInterface.encodeFunctionData("initRiverV1_2"),
    "River"
  );

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);

  // Check if all proxies already point to the new implementations
  const proxyImplPairs = [
    { proxy: "Withdraw", impl: `WithdrawV1_Implementation_${version}` },
    { proxy: "CoverageFund", impl: `CoverageFundV1_Implementation_${version}` },
    { proxy: "ELFeeRecipient", impl: `ELFeeRecipientV1_Implementation_${version}` },
    { proxy: "Allowlist", impl: `AllowlistV1_Implementation_${version}` },
    { proxy: "OperatorsRegistry", impl: `OperatorsRegistryV1_Implementation_${version}` },
    { proxy: "Oracle", impl: `OracleV1_Implementation_${version}` },
    { proxy: "RedeemManager", impl: `RedeemManagerV1_Implementation_${version}` },
    { proxy: "River", impl: `RiverV1_Implementation_${version}` },
  ];

  try {
    for (const { proxy, impl } of proxyImplPairs) {
      const proxyDeployment = await deployments.get(proxy);
      const implDeployment = await deployments.get(impl);
      const currentImpl = await getProxyImplementation(proxyDeployment.address, ethers.provider);
      if (currentImpl.toLowerCase() !== implDeployment.address.toLowerCase()) {
        return false;
      }
    }
    console.log("Skipped");
    logStepEnd(__filename);
    return true;
  } catch (_error) {
    return false;
  }
};

func.tags = ["upgrade_v1_3_0_proxies"];

export default func;
