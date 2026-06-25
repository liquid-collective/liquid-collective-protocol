import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers as EthersType } from "ethers";
import { logStep, logStepEnd } from "../../ts-utils/helpers/index";

const version = "1_3_0";

// EIP-1967 implementation storage slot
const EIP1967_IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

const VERSION_ABI = ["function version() external pure returns (string)"];
const RIVER_ABI = [
  ...VERSION_ABI,
  "function getCollector() external view returns (address)",
  "function getRedeemManager() external view returns (address)",
  "function getOperatorsRegistry() external view returns (address)",
  "function getOracle() external view returns (address)",
];
const ORACLE_ABI = [...VERSION_ABI, "function getRiver() external view returns (address)"];
const OPERATORS_REGISTRY_ABI = [...VERSION_ABI, "function getRiver() external view returns (address)"];
const REDEEM_MANAGER_ABI = [...VERSION_ABI, "function getRiver() external view returns (address)"];
const WITHDRAW_ABI = [...VERSION_ABI, "function getRiver() external view returns (address)"];
const ALLOWLIST_ABI = [
  ...VERSION_ABI,
  "function getAllower() external view returns (address)",
  "function getDenier() external view returns (address)",
];
const COVERAGE_FUND_ABI = VERSION_ABI;
const EL_FEE_RECIPIENT_ABI = VERSION_ABI;

let failures = 0;

function check(label: string, actual: string, expected: string): void {
  if (actual.toLowerCase() === expected.toLowerCase()) {
    console.log(`  ✅ ${label}: ${actual}`);
  } else {
    console.log(`  ❌ ${label}: expected ${expected}, got ${actual}`);
    failures++;
  }
}

// Call a view function on a proxy using address(0) as caller to bypass
// the transparent proxy admin restriction on view calls.
// IMPORTANT: always pass the PROXY address here, never the ProxyFirewall address.
// Firewall.sol has its own hardcoded version() = "1.3.0" — calling it on a
// ProxyFirewall would give a false positive regardless of whether the proxy
// was actually upgraded.
async function callView(
  proxyAddress: string,
  abi: string[],
  functionName: string,
  provider: EthersType.providers.Provider
): Promise<string> {
  const iface = new EthersType.utils.Interface(abi);
  const result = await provider.call({
    from: EthersType.constants.AddressZero,
    to: proxyAddress,
    data: iface.encodeFunctionData(functionName),
  });
  return iface.decodeFunctionResult(functionName, result)[0];
}

const func: DeployFunction = async function ({
  deployments,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  if (!["mainnet", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for mainnet verification");
  }

  failures = 0;

  // Load proxy deployments (stable mainnet addresses from deployments/mainnet/)
  const riverProxy             = await deployments.get("River");
  const oracleProxy            = await deployments.get("Oracle");
  const operatorsRegistryProxy = await deployments.get("OperatorsRegistry");
  const redeemManagerProxy     = await deployments.get("RedeemManager");
  const withdrawProxy          = await deployments.get("Withdraw");
  const allowlistProxy         = await deployments.get("Allowlist");
  const coverageFundProxy      = await deployments.get("CoverageFund");
  const elFeeRecipientProxy    = await deployments.get("ELFeeRecipient");

  // Load freshly-deployed v1.3.0 implementation deployments
  const riverImpl             = await deployments.get(`RiverV1_Implementation_${version}`);
  const oracleImpl            = await deployments.get(`OracleV1_Implementation_${version}`);
  const operatorsRegistryImpl = await deployments.get(`OperatorsRegistryV1_Implementation_${version}`);
  const redeemManagerImpl     = await deployments.get(`RedeemManagerV1_Implementation_${version}`);
  const withdrawImpl          = await deployments.get(`WithdrawV1_Implementation_${version}`);
  const allowlistImpl         = await deployments.get(`AllowlistV1_Implementation_${version}`);
  const coverageFundImpl      = await deployments.get(`CoverageFundV1_Implementation_${version}`);
  const elFeeRecipientImpl    = await deployments.get(`ELFeeRecipientV1_Implementation_${version}`);

  // ============================================================
  // CHECK 1: All proxies point to the new implementations
  // ============================================================
  console.log("\n=== Check 1: Implementation slots ===\n");

  const proxyImplPairs = [
    { name: "Withdraw",           proxy: withdrawProxy.address,          impl: withdrawImpl.address },
    { name: "CoverageFund",       proxy: coverageFundProxy.address,      impl: coverageFundImpl.address },
    { name: "ELFeeRecipient",     proxy: elFeeRecipientProxy.address,    impl: elFeeRecipientImpl.address },
    { name: "Allowlist",          proxy: allowlistProxy.address,         impl: allowlistImpl.address },
    { name: "OperatorsRegistry",  proxy: operatorsRegistryProxy.address, impl: operatorsRegistryImpl.address },
    { name: "Oracle",             proxy: oracleProxy.address,            impl: oracleImpl.address },
    { name: "RedeemManager",      proxy: redeemManagerProxy.address,     impl: redeemManagerImpl.address },
    { name: "River",              proxy: riverProxy.address,             impl: riverImpl.address },
  ];

  for (const { name, proxy, impl } of proxyImplPairs) {
    const raw = await ethers.provider.getStorageAt(proxy, EIP1967_IMPL_SLOT);
    const currentImpl = EthersType.utils.getAddress("0x" + raw.slice(-40));
    check(`${name} implementation`, currentImpl, impl);
  }

  // ============================================================
  // CHECK 2: All contracts report version "1.3.0"
  // ============================================================
  console.log("\n=== Check 2: Version strings ===\n");

  const versionChecks = [
    { name: "Withdraw",          proxy: withdrawProxy.address,          abi: WITHDRAW_ABI },
    { name: "CoverageFund",      proxy: coverageFundProxy.address,      abi: COVERAGE_FUND_ABI },
    { name: "ELFeeRecipient",    proxy: elFeeRecipientProxy.address,    abi: EL_FEE_RECIPIENT_ABI },
    { name: "Allowlist",         proxy: allowlistProxy.address,         abi: ALLOWLIST_ABI },
    { name: "OperatorsRegistry", proxy: operatorsRegistryProxy.address, abi: OPERATORS_REGISTRY_ABI },
    { name: "Oracle",            proxy: oracleProxy.address,            abi: ORACLE_ABI },
    { name: "RedeemManager",     proxy: redeemManagerProxy.address,     abi: REDEEM_MANAGER_ABI },
    { name: "River",             proxy: riverProxy.address,             abi: RIVER_ABI },
  ];

  for (const { name, proxy, abi } of versionChecks) {
    const v = await callView(proxy, abi, "version", ethers.provider);
    check(`${name} version`, v, "1.3.0");
  }

  // ============================================================
  // CHECK 3: Cross-contract references are intact
  // ============================================================
  console.log("\n=== Check 3: Cross-contract references ===\n");

  const riverOracle = await callView(riverProxy.address, RIVER_ABI, "getOracle", ethers.provider);
  check("River.getOracle()", riverOracle, oracleProxy.address);

  const riverRedeemManager = await callView(riverProxy.address, RIVER_ABI, "getRedeemManager", ethers.provider);
  check("River.getRedeemManager()", riverRedeemManager, redeemManagerProxy.address);

  const riverOpsRegistry = await callView(riverProxy.address, RIVER_ABI, "getOperatorsRegistry", ethers.provider);
  check("River.getOperatorsRegistry()", riverOpsRegistry, operatorsRegistryProxy.address);

  const oracleRiver = await callView(oracleProxy.address, ORACLE_ABI, "getRiver", ethers.provider);
  check("Oracle.getRiver()", oracleRiver, riverProxy.address);

  const opsRiver = await callView(operatorsRegistryProxy.address, OPERATORS_REGISTRY_ABI, "getRiver", ethers.provider);
  check("OperatorsRegistry.getRiver()", opsRiver, riverProxy.address);

  const redeemRiver = await callView(redeemManagerProxy.address, REDEEM_MANAGER_ABI, "getRiver", ethers.provider);
  check("RedeemManager.getRiver()", redeemRiver, riverProxy.address);

  const withdrawRiver = await callView(withdrawProxy.address, WITHDRAW_ABI, "getRiver", ethers.provider);
  check("Withdraw.getRiver()", withdrawRiver, riverProxy.address);

  // ============================================================
  // CHECK 4: Storage integrity post-upgrade
  // ============================================================
  console.log("\n=== Check 4: Storage integrity ===\n");

  // Allowlist.getDenier() — set to 0xe3208aa9d1186c1d1c8a5b76e794b2b68e6cb3a5
  // by initAllowlistV1_1 at v1.2.1. v1.3.0 uses plain upgradeTo so this must
  // be unchanged.
  const EXPECTED_DENIER = "0xe3208aa9d1186c1d1c8a5b76e794b2b68e6cb3a5";
  const denier = await callView(allowlistProxy.address, ALLOWLIST_ABI, "getDenier", ethers.provider);
  check("Allowlist.getDenier()", denier, EXPECTED_DENIER);

  // Allowlist.getAllower() must be non-zero
  const allower = await callView(allowlistProxy.address, ALLOWLIST_ABI, "getAllower", ethers.provider);
  if (allower === EthersType.constants.AddressZero) {
    console.log(`  ❌ Allowlist.getAllower(): is zero address`);
    failures++;
  } else {
    console.log(`  ✅ Allowlist.getAllower(): ${allower}`);
  }

  // River.getCollector() must be non-zero
  const collector = await callView(riverProxy.address, RIVER_ABI, "getCollector", ethers.provider);
  if (collector === EthersType.constants.AddressZero) {
    console.log(`  ❌ River.getCollector(): is zero address`);
    failures++;
  } else {
    console.log(`  ✅ River.getCollector(): ${collector}`);
  }

  // ============================================================
  // SUMMARY
  // ============================================================
  console.log("\n=== Summary ===\n");
  if (failures === 0) {
    console.log("  All checks passed. ✅");
  } else {
    throw new Error(`${failures} check(s) failed. See above for details.`);
  }

  logStepEnd(__filename);
};

func.skip = async function (): Promise<boolean> {
  logStep(__filename);
  return false; // always run
};

func.tags = ["verify_v1_3_0_upgrade_mainnet"];

export default func;
