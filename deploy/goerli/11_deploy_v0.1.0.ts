import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";

const func: DeployFunction = async function ({ deployments, network, getNamedAccounts }: HardhatRuntimeEnvironment) {
  if (!["goerli", "hardhat"].includes(network.name)) {
    throw new Error("Invalid network for devGoerli deployment");
  }

  const { deployer } = await getNamedAccounts();

  await deployments.deploy("RedeemManagerV1_Implementation_1_0_0", {
    contract: "RedeemManagerV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("ELFeeRecipientV1_Implementation_1_0_0", {
    contract: "ELFeeRecipientV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("OperatorsRegistryV1_Implementation_1_0_0", {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("OracleV1_Implementation_1_0_0", {
    contract: "OracleV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("RiverV1_Implementation_1_0_0", {
    contract: "RiverV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("TLCV1_Implementation_1_0_0", {
    contract: "TLCV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("WithdrawV1_Implementation_1_0_0", {
    contract: "WithdrawV1",
    from: deployer,
    log: true,
  });

  // migration and upgrade steps
  // 1. upgradeTo WithdrawContract 
  // 2. upgradeTo OperatorsRegistry 
  // 3. upgradeTo OracleContract
  // 4. upgradeTo RiverContract
  // 5. upgradeTo ELFeeRecipientContract
  // 6. upgradeTo TLCContract
  // 7. upgradeTo RedeemManager
  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
  (await isDeployed("RedeemManagerV1_Implementation_1_0_0", deployments, __filename)) &&
  (await isDeployed("ELFeeRecipientV1_Implementation_1_0_0", deployments, __filename)) &&
  (await isDeployed("OperatorsRegistryV1_Implementation_1_0_0", deployments, __filename)) &&
  (await isDeployed("OracleV1_Implementation_1_0_0", deployments, __filename)) &&
  (await isDeployed("RiverV1_Implementation_1_0_0", deployments, __filename)) &&
  (await isDeployed("WithdrawV1_Implementation_1_0_0", deployments, __filename)) &&
  (await isDeployed("TLCV1_Implementation_1_0_0", deployments, __filename));
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
