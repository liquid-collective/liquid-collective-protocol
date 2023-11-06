import { getContractAddress } from "ethers/lib/utils";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

// Deploy the following contracts:
// 1. River (River + TUPProxy + Firewall)
// 2. Oracle (Oracle + TUPProxy + Firewall)
// 3. OperatorsRegistry (OperatorsRegistry + TUPProxy + Firewall)
// 4. ELFeeRecipient (ELFeeRecipient + TUPProxy)
// 5. RedeemManager (RedeemManager + TUPProxy)
//
// Run initializations
// 1. initializeWithdrawV1 on Withdraw
// 2. initRiverV1_1 on River
// 3. forceFundedValidatorKeysEventEmission on OperatorsRegistry
//
const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  if (!["holesky", "hardhat", "local", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for devGoerli deployment");
  }
  const genesisTimestamp = 1695902400;
  const grossFee = 1250;

  const { deployer, governor, executor, proxyAdministrator, collector } = await getNamedAccounts();

  let depositContract = (await getNamedAccounts()).depositContract;

  const withdrawDeployment = await deployments.get("Withdraw");
  const WithdrawContract = await ethers.getContractAt("WithdrawV1", withdrawDeployment.address);
  const withdrawalCredentials = await WithdrawContract.getCredentials();

  const signer = await ethers.getSigner(deployer);

  const txCount = await signer.getTransactionCount();

  const futureELFeeRecipientAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 10, // proxy is in 8 txs
  });

  const futureOperatorsRegistryAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 8, // proxy is in 8 txs
  });

  const futureOracleAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 5, // proxy is in 6 txs
  });

  const futureRiverAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 2, // proxy is in 3 txs
  });

  const riverArtifact = await deployments.getArtifact("RiverV1");
  const riverInterface = new ethers.utils.Interface(riverArtifact.abi);

  const riverFirewallDeployment = await deployments.deploy("RiverFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, futureRiverAddress, [riverInterface.getSighash("depositToConsensusLayer")]],
  });

  const allowlistDeployment = await deployments.get("Allowlist");

  const riverDeployment = await deployments.deploy("River", {
    contract: "RiverV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "RiverV1_Implementation_1_0_1",
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

  await verify("TUPProxy", riverDeployment.address, []);
  await verify("RiverV1", riverDeployment.implementation, []);

  const oracleArtifact = await deployments.getArtifact("OracleV1");
  const oracleInterface = new ethers.utils.Interface(oracleArtifact.abi);

  const oracleFirewallDeployment = await deployments.deploy("OracleFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, futureOracleAddress, [oracleInterface.getSighash("removeMember")]],
  });

  await verify("Firewall", oracleFirewallDeployment.address, [
    governor,
    executor,
    futureOracleAddress,
    [oracleInterface.getSighash("removeMember")],
  ]);

  const oracleDeployment = await deployments.deploy("Oracle", {
    contract: "OracleV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "OracleV1_Implementation_1_0_0",
      execute: {
        methodName: "initOracleV1",
        args: [riverDeployment.address, oracleFirewallDeployment.address, 225, 32, 12, genesisTimestamp, 1000, 500],
      },
    },
  });

  await verify("TUPProxy", oracleDeployment.address, []);
  await verify("OracleV1", oracleDeployment.implementation, []);

  const operatorsRegistryArtifact = await deployments.getArtifact("OperatorsRegistryV1");
  const operatorsRegsitryInterface = new ethers.utils.Interface(operatorsRegistryArtifact.abi);

  const operatorsRegistryFirewallDeployment = await deployments.deploy("OperatorsRegistryFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [
      governor,
      executor,
      futureOperatorsRegistryAddress,
      [
        operatorsRegsitryInterface.getSighash("setOperatorStatus"),
        operatorsRegsitryInterface.getSighash("setOperatorName"),
        operatorsRegsitryInterface.getSighash("setOperatorLimits"),
      ],
    ],
  });

  await verify("Firewall", operatorsRegistryFirewallDeployment.address, [
    governor,
    executor,
    futureOperatorsRegistryAddress,
    [
      operatorsRegsitryInterface.getSighash("setOperatorStatus"),
      operatorsRegsitryInterface.getSighash("setOperatorName"),
      operatorsRegsitryInterface.getSighash("setOperatorLimits"),
    ],
  ]);

  const operatorsRegistryDeployment = await deployments.deploy("OperatorsRegistry", {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "OperatorsRegistryV1_Implementation_1_1_0",
      execute: {
        methodName: "initOperatorsRegistryV1",
        args: [operatorsRegistryFirewallDeployment.address, futureRiverAddress],
      },
    },
  });

  await verify("TUPProxy", operatorsRegistryDeployment.address, []);
  await verify("OperatorsRegistryV1", operatorsRegistryDeployment.implementation, []);

  const elFeeRecipientDeployment = await deployments.deploy("ELFeeRecipient", {
    contract: "ELFeeRecipientV1",
    from: deployer,
    log: true,
    proxy: {
      implementationName: "ELFeeRecipientV1_Implementation_1_0_0",
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initELFeeRecipientV1",
        args: [riverDeployment.address],
      },
    },
  });

  await verify("TUPProxy", elFeeRecipientDeployment.address, []);
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

  const redeemManagerDeployment = await deployments.deploy("RedeemManager", {
    contract: "RedeemManagerV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "RedeemManagerV1_Implementation_1_1_0",
      execute: {
        methodName: "initializeRedeemManagerV1",
        args: [riverDeployment.address],
      },
    },
  });

  await verify("TUPProxy", redeemManagerDeployment.address, []);
  await verify("RedeemManagerV1", redeemManagerDeployment.implementation, []);

  // Initializations

  let tx = await WithdrawContract.initializeWithdrawV1(riverDeployment.address);
  console.log(`Performed Withdraw.initializeWithdrawV1(${riverDeployment.address}) contract 0.6.0 upgrade:`, tx.hash);

  const epochsPerFrame = 225;
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

export default func;

