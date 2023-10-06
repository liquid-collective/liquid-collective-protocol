import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { TUPPROXY_VERSION_SLOT } from "../../ts-utils/helpers/constants";

// these steps have been done in the migration script on purpose for clarity purposes on the migration and upgrade steps
// required after the 03/23 spearbit audit
const func: DeployFunction = async function ({ deployments, network, ethers }: HardhatRuntimeEnvironment) {
  if (!["devHolesky", "hardhat","local", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for devGoerli deployment");
  }

  const redeemManagerDeployment = await deployments.get("RedeemManager");
  const epochsPerFrame = 225;
  const slotsPerEpoch = 32;
  const secondsPerSlot = 12;
  const genesisTimestamp = 1616508000;
  const epochsToAssumedFinality = 4;
  const upperBound = 1000;
  const lowerBound = 500;
  const minDailyNetCommittable = BigInt(3200) * BigInt(1e18);
  const maxDailyRelativeCommittable = 1000;

  const riverDeployment = await deployments.get("River");
  const RiverContract = await ethers.getContractAt("RiverV1", riverDeployment.address);
  const withdrawDeployment = await deployments.get("Withdraw");
  const WithdrawContract = await ethers.getContractAt("WithdrawV1", withdrawDeployment.address);
  const operatorsRegistryDeployment = await deployments.get("OperatorsRegistry");
  const OperatorsRegistryContract = await ethers.getContractAt(
    "OperatorsRegistryV1",
    operatorsRegistryDeployment.address
  );
  const oracleDeployment = await deployments.get("Oracle");
  const OracleContract = await ethers.getContractAt("OracleV1", oracleDeployment.address);

  let tx = await WithdrawContract.initializeWithdrawV1(riverDeployment.address);
  console.log(`Performed Withdraw.initializeWithdrawV1(${riverDeployment.address}) contract 0.6.0 upgrade:`, tx.hash);

  tx = await OperatorsRegistryContract.initOperatorsRegistryV1_1();
  console.log("Performed OperatorsRegistry.initOperatorsRegistryV1_1() contract 0.6.0 upgrade:", tx.hash);

  tx = await OracleContract.initOracleV1_1();
  console.log("Performed Operator.initOracleV1_1() contract 0.6.0 upgrade:", tx.hash);

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

  tx = await OperatorsRegistryContract.forceFundedValidatorKeysEventEmission(1);
  console.log(
    `Performed OperatorsRegistry.forceFundedValidatorKeysEventEmission(${1}) contract 0.6.0 migration:`,
    tx.hash
  );

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = !(
    BigInt(await ethers.provider.getStorageAt((await deployments.get("River")).address, TUPPROXY_VERSION_SLOT)) ===
      BigInt(1) &&
    BigInt(await ethers.provider.getStorageAt((await deployments.get("Withdraw")).address, TUPPROXY_VERSION_SLOT)) ===
      BigInt(0) &&
    BigInt(
      await ethers.provider.getStorageAt((await deployments.get("OperatorsRegistry")).address, TUPPROXY_VERSION_SLOT)
    ) === BigInt(1) &&
    BigInt(await ethers.provider.getStorageAt((await deployments.get("Oracle")).address, TUPPROXY_VERSION_SLOT)) ===
      BigInt(1)
  );
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
