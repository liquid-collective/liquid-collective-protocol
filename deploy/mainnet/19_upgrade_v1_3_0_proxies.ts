import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers as EthersType } from "ethers";
import { logStep, logStepEnd } from "../../ts-utils/helpers/index";

const version = "1_3_0";

// EIP-1967 implementation storage slot
const EIP1967_IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

// The on-chain proxy administrator for mainnet proxies.
// Used directly when impersonating on a Tenderly mainnet fork.
const MAINNET_PROXY_ADMINISTRATOR = "0x8EE3fC0Bcd7B57429203751C5bE5fdf1AB8409f3";

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
  if (!["mainnet", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for mainnet deployment");
  }

  const { proxyAdministrator } = await getNamedAccounts();

  const proxyTransparentArtifact = await deployments.getArtifact("ITransparentUpgradeableProxy");
  const proxyTransparentInterface = new ethers.utils.Interface(proxyTransparentArtifact.abi);

  // On a Tenderly mainnet fork the proxies' on-chain admin is the real mainnet
  // proxyAdministrator, not the tenderly-configured named account. Impersonate
  // that address directly via the RPC so upgradeTo calls are accepted.
  let signer: EthersType.Signer;

  if (network.name === "tenderly") {
    await network.provider.request({
      method: "tenderly_setBalance",
      params: [MAINNET_PROXY_ADMINISTRATOR, "0x56BC75E2D63100000"], // 100 ETH
    });
    const directProvider = new EthersType.providers.JsonRpcProvider(
      (network.config as any).url
    );
    signer = directProvider.getSigner(MAINNET_PROXY_ADMINISTRATOR);
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

  // Load ProxyFirewall addresses (admins of the firewalled proxies)
  const riverProxyFirewall = await deployments.get("RiverProxyFirewall");
  const oracleProxyFirewall = await deployments.get("OracleProxyFirewall");
  const operatorsRegistryProxyFirewall = await deployments.get("OperatorsRegistryProxyFirewall");
  const redeemManagerProxyFirewall = await deployments.get("RedeemManagerProxyFirewall");
  const allowlistProxyFirewall = await deployments.get("AllowlistProxyFirewall");

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

  // All 8 proxies use upgradeTo with no init call.
  //
  // The initializers called in the hoodi/devHoodi scripts have already run on
  // mainnet (Allowlist/OperatorsRegistry/Oracle/RedeemManager at InitVersion 2,
  // River at InitVersion 3). Calling upgradeToAndCall with those init selectors
  // would revert at the Solidity version guard.

  console.log("\n=== Phase 1: Simple upgrades — direct-admin proxies ===\n");

  await doUpgradeTo(
    withdrawProxy.address,
    withdrawProxy.address,
    withdrawImpl.address,
    "Withdraw"
  );

  await doUpgradeTo(
    coverageFundProxy.address,
    coverageFundProxy.address,
    coverageFundImpl.address,
    "CoverageFund"
  );

  await doUpgradeTo(
    elFeeRecipientProxy.address,
    elFeeRecipientProxy.address,
    elFeeRecipientImpl.address,
    "ELFeeRecipient"
  );

  console.log("\n=== Phase 2: Simple upgrades — firewalled proxies ===\n");

  await doUpgradeTo(
    allowlistProxy.address,
    allowlistProxyFirewall.address,
    allowlistImpl.address,
    "Allowlist"
  );

  await doUpgradeTo(
    operatorsRegistryProxy.address,
    operatorsRegistryProxyFirewall.address,
    operatorsRegistryImpl.address,
    "OperatorsRegistry"
  );

  await doUpgradeTo(
    oracleProxy.address,
    oracleProxyFirewall.address,
    oracleImpl.address,
    "Oracle"
  );

  await doUpgradeTo(
    redeemManagerProxy.address,
    redeemManagerProxyFirewall.address,
    redeemManagerImpl.address,
    "RedeemManager"
  );

  console.log("\n=== Phase 3: River upgrade ===\n");

  await doUpgradeTo(
    riverProxy.address,
    riverProxyFirewall.address,
    riverImpl.address,
    "River"
  );

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);

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

func.tags = ["upgrade_v1_3_0_proxies_mainnet"];

export default func;
