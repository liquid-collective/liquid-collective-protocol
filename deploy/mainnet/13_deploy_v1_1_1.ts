import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";

const func: DeployFunction = async function ({
  deployments,
  network,
  getNamedAccounts,
  ethers,
}: HardhatRuntimeEnvironment) {
  if (!["mainnet", "hardhat", "localhost", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for mainnet deployment");
  }

  const { deployer, executor, denier } = await getNamedAccounts();

  const signer = await ethers.getSigner(executor);

  // const allowlistNewImplementationDeployment = await deployments.deploy("AllowlistV1_Implementation_1_1_1", {
  //   contract: "AllowlistV1",
  //   from: deployer,
  //   log: true,
  // });
  // console.log(allowlistNewImplementationDeployment.address);

  // upgrade steps
  // upgradeToAndCall

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("AllowlistV1_Implementation_1_1_1", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
