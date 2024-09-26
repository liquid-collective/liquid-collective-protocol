import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getContractAddress } from "ethers/lib/utils";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, ethers }: HardhatRuntimeEnvironment) {
  // const { deployer, proxyAdministrator, governor, executor } = await getNamedAccounts();

  // const signer = await ethers.getSigner(deployer);

  // const riverDeployment = await deployments.get("River");

  // await deployments.deploy("ProtocolMetrics", {
  //   contract: "ProtocolMetricsV1",
  //   from: deployer,
  //   log: true,
  //   proxy: {
  //     owner: proxyAdministrator,
  //     proxyContract: "TUPProxy",
  //     implementationName: "ProtocolMetricsV1",
  //     execute: {
  //       methodName: "initProtocolMetricsV1",
  //       args: [riverDeployment.address],
  //     },
  //   },
  // });

  // logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("RateProvider", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
