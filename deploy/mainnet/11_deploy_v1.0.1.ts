import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";

const func: DeployFunction = async function ({ deployments, network, getNamedAccounts }: HardhatRuntimeEnvironment) {
  if (!["mainnet", "hardhat", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for mainnet deployment");
  }

  const { deployer } = await getNamedAccounts();

  // await deployments.deploy("RiverV1_Implementation_1_0_1", {
  //   contract: "RiverV1",
  //   from: deployer,
  //   log: true,
  // });
  
  // await deployments.deploy("OperatorsRegistryV1_Implementation_1_0_1", {
  //   contract: "OperatorsRegistryV1",
  //   from: deployer,
  //   log: true,
  // });

  // migration and upgrade steps
  // 1. upgradeTo OperatorsRegistry 
  // 2. upgradeToAndCall RiverContract + RiverContract.initRiverV1_2()
  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
  (await isDeployed("OperatorsRegistryV1_Implementation_1_0_1", deployments, __filename)) &&
  (await isDeployed("RiverV1_Implementation_1_0_1", deployments, __filename))
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
