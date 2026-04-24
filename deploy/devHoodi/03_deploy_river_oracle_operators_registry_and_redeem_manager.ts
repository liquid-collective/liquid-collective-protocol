import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers as EthersType } from "ethers";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

// Deploy the following contracts:
// 1. River (River + TUPProxy + Firewall + ProxyFirewall)
// 2. Oracle (Oracle + TUPProxy + Firewall + ProxyFirewall)
// 3. OperatorsRegistry (OperatorsRegistry + TUPProxy + Firewall + ProxyFirewall)
// 4. ELFeeRecipient (ELFeeRecipient + TUPProxy)
// 5. RedeemManager (RedeemManager + TUPProxy + ProxyFirewall)
//
// Run initializations
// 1. initializeWithdrawV1 on Withdraw
// 2. initRiverV1_1 on River
// 3. forceFundedValidatorKeysEventEmission on OperatorsRegistry
//
// IMPLEMENTATION NOTE (Option C):
// All proxies are deployed first with `deployer` as temporary admin (no execute/init).
// Firewalls are then deployed with the actual proxy addresses (no nonce pre-computation needed).
// Each proxy is initialized via upgradeToAndCall from the deployer, then admin is
// transferred to the corresponding ProxyFirewall. All steps are idempotent.

const implementationVersion = "1_2_1";

// EIP-1967 admin storage slot
const EIP1967_ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

// ABI fragments for proxy admin operations
const PROXY_ADMIN_ABI = [
  "function upgradeToAndCall(address newImplementation, bytes calldata data) external payable",
  "function changeAdmin(address newAdmin) external",
];

// Check if a proxy's underlying contract is initialized by calling a view function
// Uses address(0) as caller to bypass the transparent proxy admin restriction.
async function isProxyInitialized(
  proxyAddress: string,
  abi: any[],
  viewFunction: string,
  provider: EthersType.providers.Provider
): Promise<boolean> {
  const iface = new EthersType.utils.Interface(abi);
  try {
    const result = await provider.call({
      from: EthersType.constants.AddressZero,
      to: proxyAddress,
      data: iface.encodeFunctionData(viewFunction),
    });
    const decoded = iface.decodeFunctionResult(viewFunction, result);
    return decoded[0] !== EthersType.constants.AddressZero;
  } catch (_error) {
    return false;
  }
}

// Read the current admin of a proxy via the EIP-1967 storage slot
async function getProxyAdmin(proxyAddress: string, provider: EthersType.providers.Provider): Promise<string> {
  const raw = await provider.getStorageAt(proxyAddress, EIP1967_ADMIN_SLOT);
  return EthersType.utils.getAddress("0x" + raw.slice(-40));
}

// Transfer the proxy admin to targetAdmin if not already set
async function transferProxyAdminIfNeeded(
  proxyAddress: string,
  targetAdmin: string,
  signer: EthersType.Signer,
  provider: EthersType.providers.Provider
): Promise<void> {
  const currentAdmin = await getProxyAdmin(proxyAddress, provider);
  if (currentAdmin.toLowerCase() === targetAdmin.toLowerCase()) {
    console.log(`  Proxy admin already set to ${targetAdmin}, skipping transfer.`);
    return;
  }
  console.log(`  Transferring proxy admin from ${currentAdmin} to ${targetAdmin}...`);
  const proxy = new EthersType.Contract(proxyAddress, PROXY_ADMIN_ABI, signer);
  const tx = await proxy.changeAdmin(targetAdmin);
  await tx.wait();
  console.log(`  Proxy admin transferred. tx: ${tx.hash}`);
}

// Initialize a proxy via upgradeToAndCall if not yet initialized
async function initializeProxyIfNeeded(
  proxyAddress: string,
  implementationAddress: string,
  initCalldata: string,
  label: string,
  abi: any[],
  checkFunction: string,
  signer: EthersType.Signer,
  provider: EthersType.providers.Provider
): Promise<void> {
  const initialized = await isProxyInitialized(proxyAddress, abi, checkFunction, provider);
  if (initialized) {
    console.log(`  ${label} already initialized, skipping.`);
    return;
  }
  console.log(`  Initializing ${label}...`);
  const proxy = new EthersType.Contract(proxyAddress, PROXY_ADMIN_ABI, signer);
  const tx = await proxy.upgradeToAndCall(implementationAddress, initCalldata);
  await tx.wait();
  console.log(`  ${label} initialized. tx: ${tx.hash}`);
}

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  if (!["hardhat", "local", "tenderly", "hoodi", "devHoodi"].includes(network.name)) {
    throw new Error("Invalid network for hoodi deployment");
  }
  const genesisTimestamp = 1742213400;
  const grossFee = 1000;

  const { deployer, governor, executor, proxyAdministrator, collector } = await getNamedAccounts();

  let depositContract = (await getNamedAccounts()).depositContract;

  const withdrawDeployment = await deployments.get("Withdraw");
  const WithdrawContract = await ethers.getContractAt("WithdrawV1", withdrawDeployment.address);
  const withdrawalCredentials = await WithdrawContract.getCredentials();

  const allowlistDeployment = await deployments.get("Allowlist");
  const proxyArtifact = await deployments.getArtifact("TUPProxy");
  const proxyInterface = new ethers.utils.Interface(proxyArtifact.abi);

  const signer = await ethers.getSigner(deployer);

  // ============================================================
  // PHASE 1: Deploy all proxies with deployer as temporary admin.
  //          No execute — proxies are uninitialized at this stage.
  //          All actual proxy addresses are now known.
  // ============================================================

  const riverArtifact = await deployments.getArtifact("RiverV1");
  const riverInterface = new ethers.utils.Interface(riverArtifact.abi);

  const riverDeployment = await deployments.deploy("River", {
    contract: "RiverV1",
    from: deployer,
    log: true,
    proxy: {
      owner: deployer,
      proxyContract: "TUPProxy",
      implementationName: `RiverV1_Implementation_${implementationVersion}`,
    },
  });
  await verify("TUPProxy", riverDeployment.address, riverDeployment.args, riverDeployment.libraries);
  await verify("RiverV1", riverDeployment.implementation, []);

  const oracleArtifact = await deployments.getArtifact("OracleV1");
  const oracleInterface = new ethers.utils.Interface(oracleArtifact.abi);

  const oracleDeployment = await deployments.deploy("Oracle", {
    contract: "OracleV1",
    from: deployer,
    log: true,
    proxy: {
      owner: deployer,
      proxyContract: "TUPProxy",
      implementationName: `OracleV1_Implementation_${implementationVersion}`,
    },
  });
  await verify("TUPProxy", oracleDeployment.address, oracleDeployment.args, oracleDeployment.libraries);
  await verify("OracleV1", oracleDeployment.implementation, []);

  const operatorsRegistryArtifact = await deployments.getArtifact("OperatorsRegistryV1");
  const operatorsRegistryInterface = new ethers.utils.Interface(operatorsRegistryArtifact.abi);

  const operatorsRegistryDeployment = await deployments.deploy("OperatorsRegistry", {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
    proxy: {
      owner: deployer,
      proxyContract: "TUPProxy",
      implementationName: `OperatorsRegistryV1_Implementation_${implementationVersion}`,
    },
  });
  await verify(
    "TUPProxy",
    operatorsRegistryDeployment.address,
    operatorsRegistryDeployment.args,
    operatorsRegistryDeployment.libraries
  );
  await verify("OperatorsRegistryV1", operatorsRegistryDeployment.implementation, []);

  const elFeeRecipientArtifact = await deployments.getArtifact("ELFeeRecipientV1");
  const elFeeRecipientInterface = new ethers.utils.Interface(elFeeRecipientArtifact.abi);

  const elFeeRecipientDeployment = await deployments.deploy("ELFeeRecipient", {
    contract: "ELFeeRecipientV1",
    from: deployer,
    log: true,
    proxy: {
      owner: deployer,
      proxyContract: "TUPProxy",
      implementationName: `ELFeeRecipientV1_Implementation_${implementationVersion}`,
    },
  });
  await verify(
    "TUPProxy",
    elFeeRecipientDeployment.address,
    elFeeRecipientDeployment.args,
    elFeeRecipientDeployment.libraries
  );
  await verify("ELFeeRecipientV1", elFeeRecipientDeployment.implementation, []);

  const redeemManagerArtifact = await deployments.getArtifact("RedeemManagerV1");
  const redeemManagerInterface = new ethers.utils.Interface(redeemManagerArtifact.abi);

  const redeemManagerDeployment = await deployments.deploy("RedeemManager", {
    contract: "RedeemManagerV1",
    from: deployer,
    log: true,
    proxy: {
      owner: deployer,
      proxyContract: "TUPProxy",
      implementationName: `RedeemManagerV1_Implementation_${implementationVersion}`,
    },
  });
  await verify(
    "TUPProxy",
    redeemManagerDeployment.address,
    redeemManagerDeployment.args,
    redeemManagerDeployment.libraries
  );
  await verify("RedeemManagerV1", redeemManagerDeployment.implementation, []);

  // ============================================================
  // PHASE 2: Deploy all Firewalls with actual proxy addresses.
  //          No nonce pre-computation needed — addresses are known.
  // ============================================================

  const riverFirewallDeployment = await deployments.deploy("RiverFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, riverDeployment.address, []],
  });
  await verify("Firewall", riverFirewallDeployment.address, riverFirewallDeployment.args);

  const riverProxyFirewallDeployment = await deployments.deploy("RiverProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, riverDeployment.address, [proxyInterface.getSighash("pause()")]],
  });
  await verify("Firewall", riverProxyFirewallDeployment.address, riverProxyFirewallDeployment.args);

  const oracleFirewallDeployment = await deployments.deploy("OracleFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, oracleDeployment.address, []],
  });
  await verify("Firewall", oracleFirewallDeployment.address, oracleFirewallDeployment.args);

  const oracleProxyFirewall = await deployments.deploy("OracleProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, oracleDeployment.address, [proxyInterface.getSighash("pause()")]],
  });
  await verify("Firewall", oracleProxyFirewall.address, oracleProxyFirewall.args);

  const operatorsRegistryFirewallDeployment = await deployments.deploy("OperatorsRegistryFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [
      governor,
      executor,
      operatorsRegistryDeployment.address,
      [operatorsRegistryInterface.getSighash("setOperatorLimits")],
    ],
  });
  await verify("Firewall", operatorsRegistryFirewallDeployment.address, operatorsRegistryFirewallDeployment.args);

  const operatorsRegistryProxyFirewallDeployment = await deployments.deploy("OperatorsRegistryProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, operatorsRegistryDeployment.address, [proxyInterface.getSighash("pause()")]],
  });
  await verify(
    "Firewall",
    operatorsRegistryProxyFirewallDeployment.address,
    operatorsRegistryProxyFirewallDeployment.args
  );

  const redeemManagerProxyFirewall = await deployments.deploy("RedeemManagerProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, redeemManagerDeployment.address, [proxyInterface.getSighash("pause()")]],
  });
  await verify("Firewall", redeemManagerProxyFirewall.address, redeemManagerProxyFirewall.args);

  // ============================================================
  // PHASE 3: Initialize all proxies via upgradeToAndCall.
  //          Idempotent: skipped if proxy already initialized.
  // ============================================================

  await initializeProxyIfNeeded(
    riverDeployment.address,
    riverDeployment.implementation,
    riverInterface.encodeFunctionData("initRiverV1", [
      depositContract,
      elFeeRecipientDeployment.address,
      withdrawalCredentials,
      oracleDeployment.address,
      riverFirewallDeployment.address,
      allowlistDeployment.address,
      operatorsRegistryDeployment.address,
      collector,
      grossFee,
    ]),
    "River",
    riverArtifact.abi,
    "getOracle",
    signer,
    ethers.provider
  );

  await initializeProxyIfNeeded(
    oracleDeployment.address,
    oracleDeployment.implementation,
    oracleInterface.encodeFunctionData("initOracleV1", [
      riverDeployment.address,
      oracleFirewallDeployment.address,
      225,
      32,
      12,
      genesisTimestamp,
      1000,
      500,
    ]),
    "Oracle",
    oracleArtifact.abi,
    "getRiver",
    signer,
    ethers.provider
  );

  await initializeProxyIfNeeded(
    operatorsRegistryDeployment.address,
    operatorsRegistryDeployment.implementation,
    operatorsRegistryInterface.encodeFunctionData("initOperatorsRegistryV1", [
      operatorsRegistryFirewallDeployment.address,
      riverDeployment.address,
    ]),
    "OperatorsRegistry",
    operatorsRegistryArtifact.abi,
    "getRiver",
    signer,
    ethers.provider
  );

  // ELFeeRecipientV1 has no getRiver() getter, so we check initialization by reading
  // the RiverAddress storage slot directly: bytes32(uint256(keccak256("river.state.riverAddress")) - 1)
  const ELFEE_RIVER_SLOT = EthersType.BigNumber.from(
    EthersType.utils.keccak256(EthersType.utils.toUtf8Bytes("river.state.riverAddress"))
  )
    .sub(1)
    .toHexString();
  const elFeeRiverRaw = await ethers.provider.getStorageAt(elFeeRecipientDeployment.address, ELFEE_RIVER_SLOT);
  const elFeeRiverAddress = EthersType.utils.getAddress("0x" + elFeeRiverRaw.slice(-40));
  if (elFeeRiverAddress === EthersType.constants.AddressZero) {
    console.log("  Initializing ELFeeRecipient...");
    const elFeeProxy = new EthersType.Contract(elFeeRecipientDeployment.address, PROXY_ADMIN_ABI, signer);
    const tx = await elFeeProxy.upgradeToAndCall(
      elFeeRecipientDeployment.implementation,
      elFeeRecipientInterface.encodeFunctionData("initELFeeRecipientV1", [riverDeployment.address])
    );
    await tx.wait();
    console.log(`  ELFeeRecipient initialized. tx: ${tx.hash}`);
  } else {
    console.log("  ELFeeRecipient already initialized, skipping.");
  }

  await initializeProxyIfNeeded(
    redeemManagerDeployment.address,
    redeemManagerDeployment.implementation,
    redeemManagerInterface.encodeFunctionData("initializeRedeemManagerV1", [riverDeployment.address]),
    "RedeemManager",
    redeemManagerArtifact.abi,
    "getRiver",
    signer,
    ethers.provider
  );

  // ============================================================
  // PHASE 4: Transfer proxy admins to their respective Firewalls.
  //          Idempotent: skipped if admin already transferred.
  // ============================================================

  await transferProxyAdminIfNeeded(
    riverDeployment.address,
    riverProxyFirewallDeployment.address,
    signer,
    ethers.provider
  );

  await transferProxyAdminIfNeeded(
    oracleDeployment.address,
    oracleProxyFirewall.address,
    signer,
    ethers.provider
  );

  await transferProxyAdminIfNeeded(
    operatorsRegistryDeployment.address,
    operatorsRegistryProxyFirewallDeployment.address,
    signer,
    ethers.provider
  );

  await transferProxyAdminIfNeeded(
    elFeeRecipientDeployment.address,
    proxyAdministrator,
    signer,
    ethers.provider
  );

  await transferProxyAdminIfNeeded(
    redeemManagerDeployment.address,
    redeemManagerProxyFirewall.address,
    signer,
    ethers.provider
  );

  // ============================================================
  // PHASE 5: Post-initialization calls.
  //          Idempotent: each call checks on-chain state first.
  // ============================================================

  // Withdraw.initializeWithdrawV1: idempotent via Withdraw.getRiver()
  const withdrawRiver = await WithdrawContract.getRiver().catch(() => EthersType.constants.AddressZero);
  if (withdrawRiver === EthersType.constants.AddressZero) {
    const tx = await WithdrawContract.initializeWithdrawV1(riverDeployment.address);
    await tx.wait();
    console.log(`Performed Withdraw.initializeWithdrawV1(${riverDeployment.address}):`, tx.hash);
  } else {
    console.log(`Withdraw already initialized with river ${withdrawRiver}, skipping.`);
  }

  // River.initRiverV1_1: idempotent via River.getRedeemManager()
  const epochsPerFrame = 2;
  const slotsPerEpoch = 32;
  const secondsPerSlot = 12;
  const epochsToAssumedFinality = 4;
  const upperBound = 1000;
  const lowerBound = 500;
  const minDailyNetCommittable = BigInt(3200) * BigInt(1e18);
  const maxDailyRelativeCommittable = 1000;

  const RiverContract = await ethers.getContractAt("RiverV1", riverDeployment.address);

  const riverRedeemManager = await RiverContract.getRedeemManager().catch(() => EthersType.constants.AddressZero);
  if (riverRedeemManager === EthersType.constants.AddressZero) {
    const tx = await RiverContract.initRiverV1_1(
      redeemManagerDeployment.address,
      epochsPerFrame,
      slotsPerEpoch,
      secondsPerSlot,
      genesisTimestamp,
      epochsToAssumedFinality,
      upperBound,
      lowerBound,
      minDailyNetCommittable,
      maxDailyRelativeCommittable
    );
    await tx.wait();
    console.log(
      `Performed River.initRiverV1_1(${[
        redeemManagerDeployment.address,
        epochsPerFrame,
        slotsPerEpoch,
        secondsPerSlot,
        genesisTimestamp,
        epochsToAssumedFinality,
        upperBound,
        lowerBound,
        minDailyNetCommittable,
        maxDailyRelativeCommittable,
      ]
        .map((x) => x.toString())
        .join(", ")}):`,
      tx.hash
    );
  } else {
    console.log(`River.initRiverV1_1 already called (redeemManager=${riverRedeemManager}), skipping.`);
  }

  const OperatorsRegistryContract = await ethers.getContractAt(
    "OperatorsRegistryV1",
    operatorsRegistryDeployment.address
  );
  try {
    const tx = await OperatorsRegistryContract.forceFundedValidatorKeysEventEmission(1);
    await tx.wait();
    console.log(
      `Performed OperatorsRegistry.forceFundedValidatorKeysEventEmission(${1}) contract 0.6.0 migration:`,
      tx.hash
    );
  } catch (e: any) {
    if (e.message?.includes("FundedKeyEventMigrationComplete") || e.error?.message?.includes("FundedKeyEventMigrationComplete")) {
      console.log("OperatorsRegistry funded key event migration already complete, skipping.");
    } else {
      throw e;
    }
  }

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  // Check proxy artifacts exist AND that post-initialization completed (River has a RedeemManager
  // set, which is only true after initRiverV1_1 in Phase 5). This ensures re-runs still execute
  // recovery steps when proxies exist but later-phase initialization failed.
  const proxiesDeployed =
    (await isDeployed("River", deployments, __filename)) &&
    (await isDeployed("Oracle", deployments, __filename)) &&
    (await isDeployed("OperatorsRegistry", deployments, __filename)) &&
    (await isDeployed("ELFeeRecipient", deployments, __filename)) &&
    (await isDeployed("RedeemManager", deployments, __filename));

  if (!proxiesDeployed) return false;

  try {
    const riverDeployment = await deployments.get("River");
    const riverInterface = new ethers.utils.Interface([
      "function getRedeemManager() external view returns (address)",
    ]);
    const result = await ethers.provider.call({
      from: ethers.constants.AddressZero,
      to: riverDeployment.address,
      data: riverInterface.encodeFunctionData("getRedeemManager"),
    });
    const [redeemManager] = riverInterface.decodeFunctionResult("getRedeemManager", result);
    const shouldSkip = redeemManager !== ethers.constants.AddressZero;
    if (shouldSkip) {
      console.log("Skipped");
      logStepEnd(__filename);
    }
    return shouldSkip;
  } catch (_error) {
    return false;
  }
};

func.tags = ["all", "core"];

export default func;
