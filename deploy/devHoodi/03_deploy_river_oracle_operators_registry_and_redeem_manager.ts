import { getContractAddress } from "ethers/lib/utils";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
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

const implementationVersion = "1_2_1";

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  if (!["hardhat", "local", "tenderly", "hoodi", "devHoodi", "kurtosis"].includes(network.name)) {
    throw new Error("Invalid network for hoodi deployment");
  }
  const genesisTimestamp = 1742213400;
  const grossFee = 1000;

  const { deployer, governor, executor, proxyAdministrator, collector } = await getNamedAccounts();

  let depositContract = (await getNamedAccounts()).depositContract;

  const withdrawDeployment = await deployments.get("Withdraw");
  const WithdrawContract = await ethers.getContractAt("WithdrawV1", withdrawDeployment.address);
  const withdrawalCredentials = await WithdrawContract.getCredentials();
  const proxyArtifact = await deployments.getArtifact("TUPProxy");
  const proxyInterface = new ethers.utils.Interface(proxyArtifact.abi);

  const signer = await ethers.getSigner(deployer);

  const txCount = await signer.getTransactionCount();

  const futureELFeeRecipientAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 13, // proxy is in 14 txs
  });

  const futureOperatorsRegistryAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 11, // proxy is in 12 txs
  });

  const futureOracleAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 7, // proxy is in 8 txs
  });

  const futureRiverAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 3, // proxy is in 4 txs
  });

  const riverArtifact = await deployments.getArtifact("RiverV1");
  const riverInterface = new ethers.utils.Interface(riverArtifact.abi);

  const riverFirewallDeployment = await deployments.deploy("RiverFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, futureRiverAddress, []],
  });
  await verify("Firewall", riverFirewallDeployment.address, riverFirewallDeployment.args);

  const riverProxyFirewallDeployment = await deployments.deploy("RiverProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, futureRiverAddress, [proxyInterface.getSighash("pause()")]],
  });
  await verify("Firewall", riverProxyFirewallDeployment.address, riverProxyFirewallDeployment.args);

  const allowlistDeployment = await deployments.get("Allowlist");

  const riverDeployment = await deployments.deploy("River", {
    contract: "RiverV1",
    from: deployer,
    log: true,
    proxy: {
      owner: riverProxyFirewallDeployment.address,
      proxyContract: "TUPProxy",
      implementationName: `RiverV1_Implementation_${implementationVersion}`,
      execute: {
        methodName: "initRiverV1",
        args: [
          depositContract,
          futureELFeeRecipientAddress,
          withdrawalCredentials,
          futureOracleAddress,
          riverFirewallDeployment.address,
          allowlistDeployment.address,
          futureOperatorsRegistryAddress,
          collector,
          grossFee,
        ],
      },
    },
  });

  await verify("TUPProxy", riverDeployment.address, riverDeployment.args, riverDeployment.libraries);
  await verify("RiverV1", riverDeployment.implementation, []);

  const oracleArtifact = await deployments.getArtifact("OracleV1");
  const oracleInterface = new ethers.utils.Interface(oracleArtifact.abi);

  const oracleFirewallDeployment = await deployments.deploy("OracleFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, futureOracleAddress, []],
  });

  await verify("Firewall", oracleFirewallDeployment.address, [governor, executor, futureOracleAddress, []]);
  const oracleProxyFirewall = await deployments.deploy("OracleProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, futureOracleAddress, [proxyInterface.getSighash("pause()")]],
  });
  await verify("Firewall", oracleProxyFirewall.address, oracleProxyFirewall.args);

  const oracleDeployment = await deployments.deploy("Oracle", {
    contract: "OracleV1",
    from: deployer,
    log: true,
    proxy: {
      owner: oracleProxyFirewall.address,
      proxyContract: "TUPProxy",
      implementationName: `OracleV1_Implementation_${implementationVersion}`,
      execute: {
        methodName: "initOracleV1",
        args: [riverDeployment.address, oracleFirewallDeployment.address, 225, 32, 12, genesisTimestamp, 1000, 500],
      },
    },
  });

  await verify("TUPProxy", oracleDeployment.address, oracleDeployment.args, oracleDeployment.libraries);
  await verify("OracleV1", oracleDeployment.implementation, []);

  const operatorsRegistryArtifact = await deployments.getArtifact("OperatorsRegistryV1");
  const operatorsRegistryInterface = new ethers.utils.Interface(operatorsRegistryArtifact.abi);

  const operatorsRegistryFirewallDeployment = await deployments.deploy("OperatorsRegistryFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [
      governor,
      executor,
      futureOperatorsRegistryAddress,
      [operatorsRegistryInterface.getSighash("setOperatorLimits")],
    ],
  });

  await verify("Firewall", operatorsRegistryFirewallDeployment.address, [
    governor,
    executor,
    futureOperatorsRegistryAddress,
    [operatorsRegistryInterface.getSighash("setOperatorLimits")],
  ]);

  const operatorsRegistryProxyFirewallDeployment = await deployments.deploy("OperatorsRegistryProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, futureOperatorsRegistryAddress, [proxyInterface.getSighash("pause()")]],
  });
  await verify(
    "Firewall",
    operatorsRegistryProxyFirewallDeployment.address,
    operatorsRegistryProxyFirewallDeployment.args
  );

  const operatorsRegistryDeployment = await deployments.deploy("OperatorsRegistry", {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
    proxy: {
      owner: operatorsRegistryProxyFirewallDeployment.address,
      proxyContract: "TUPProxy",
      implementationName: `OperatorsRegistryV1_Implementation_${implementationVersion}`,
      execute: {
        methodName: "initOperatorsRegistryV1",
        args: [operatorsRegistryFirewallDeployment.address, futureRiverAddress],
      },
    },
  });

  await verify(
    "TUPProxy",
    operatorsRegistryDeployment.address,
    operatorsRegistryDeployment.args,
    operatorsRegistryDeployment.libraries
  );
  await verify("OperatorsRegistryV1", operatorsRegistryDeployment.implementation, []);

  const elFeeRecipientDeployment = await deployments.deploy("ELFeeRecipient", {
    contract: "ELFeeRecipientV1",
    from: deployer,
    log: true,
    proxy: {
      implementationName: `ELFeeRecipientV1_Implementation_${implementationVersion}`,
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initELFeeRecipientV1",
        args: [riverDeployment.address],
      },
    },
  });

  await verify(
    "TUPProxy",
    elFeeRecipientDeployment.address,
    elFeeRecipientDeployment.args,
    elFeeRecipientDeployment.libraries
  );
  await verify("ELFeeRecipientV1", elFeeRecipientDeployment.implementation, []);

  if (riverDeployment.address !== futureRiverAddress) {
    throw new Error(`Invalid future river address computation ${futureRiverAddress} != ${riverDeployment.address}`);
  }

  if (oracleDeployment.address !== futureOracleAddress) {
    throw new Error(`Invalid future oracle address computation ${futureRiverAddress} != ${riverDeployment.address}`);
  }

  if (elFeeRecipientDeployment.address !== futureELFeeRecipientAddress) {
    throw new Error(
      `Invalid future EL Fee Recipient address computation ${futureELFeeRecipientAddress} != ${elFeeRecipientDeployment.address}`
    );
  }

  if (operatorsRegistryDeployment.address !== futureOperatorsRegistryAddress) {
    throw new Error(
      `Invalid future Operators Registry address computation ${futureOperatorsRegistryAddress} != ${operatorsRegistryDeployment.address}`
    );
  }

  const riverInstance = new ethers.Contract(riverDeployment.address, riverDeployment.abi, ethers.provider);

  if ((await riverInstance.getOracle()).toLowerCase() !== oracleDeployment.address.toLowerCase()) {
    throw new Error(`Invalid oracle address provided by River`);
  }

  const oracleInstance = new ethers.Contract(oracleDeployment.address, oracleDeployment.abi, ethers.provider);

  if ((await oracleInstance.getRiver()).toLowerCase() !== riverDeployment.address.toLowerCase()) {
    throw new Error(`Invalid river address provided by Oracle`);
  }

  const futureRedeemManagerAddress = getContractAddress({
    from: deployer,
    nonce: (await signer.getTransactionCount()) + 2,
  });

  const redeemManagerProxyFirewall = await deployments.deploy("RedeemManagerProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, futureRedeemManagerAddress, [proxyInterface.getSighash("pause()")]],
  });

  await verify("Firewall", redeemManagerProxyFirewall.address, redeemManagerProxyFirewall.args);

  const redeemManagerDeployment = await deployments.deploy("RedeemManager", {
    contract: "RedeemManagerV1",
    from: deployer,
    log: true,
    proxy: {
      owner: redeemManagerProxyFirewall.address,
      proxyContract: "TUPProxy",
      implementationName: `RedeemManagerV1_Implementation_${implementationVersion}`,
      execute: {
        methodName: "initializeRedeemManagerV1",
        args: [riverDeployment.address],
      },
    },
  });

  if (redeemManagerDeployment.address !== futureRedeemManagerAddress) {
    throw new Error(
      `Invalid future redeem manager address computation ${futureRedeemManagerAddress} != ${redeemManagerDeployment.address}`
    );
  }

  await verify(
    "TUPProxy",
    redeemManagerDeployment.address,
    redeemManagerDeployment.args,
    redeemManagerDeployment.libraries
  );
  await verify("RedeemManagerV1", redeemManagerDeployment.implementation, []);

  // Initializations

  let tx = await WithdrawContract.initializeWithdrawV1(riverDeployment.address);
  console.log(`Performed Withdraw.initializeWithdrawV1(${riverDeployment.address}) contract 0.6.0 upgrade:`, tx.hash);

  const epochsPerFrame = 2;
  const slotsPerEpoch = 32;
  const secondsPerSlot = 12;
  const epochsToAssumedFinality = 4;
  const upperBound = 1000;
  const lowerBound = 500;
  const minDailyNetCommittable = BigInt(3200) * BigInt(1e18);
  const maxDailyRelativeCommittable = 1000;

  const RiverContract = await ethers.getContractAt("RiverV1", riverDeployment.address);
  tx = await RiverContract.initRiverV1_1(
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
      .join(", ")}) contract 0.6.0 upgrade:`,
    tx.hash
  );

  const OperatorsRegistryContract = await ethers.getContractAt(
    "OperatorsRegistryV1",
    operatorsRegistryDeployment.address
  );
  tx = await OperatorsRegistryContract.forceFundedValidatorKeysEventEmission(1);
  console.log(
    `Performed OperatorsRegistry.forceFundedValidatorKeysEventEmission(${1}) contract 0.6.0 migration:`,
    tx.hash
  );

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
    (await isDeployed("River", deployments, __filename)) &&
    (await isDeployed("Oracle", deployments, __filename)) &&
    (await isDeployed("OperatorsRegistry", deployments, __filename)) &&
    (await isDeployed("ELFeeRecipient", deployments, __filename)) &&
    (await isDeployed("RedeemManager", deployments, __filename));
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

func.tags = ["all", "core"];

export default func;
