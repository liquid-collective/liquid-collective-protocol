import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, network }: HardhatRuntimeEnvironment) {
  if (!["devGoerli", "hardhat"].includes(network.name)) {
    throw new Error("Invalid network for devGoerli deployment");
  }
  const { deployer, proxyAdministrator } = await getNamedAccounts();

  const riverDeployment = await deployments.get("River");

  await deployments.deploy("CoverageFund", {
    contract: "CoverageFundV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "CoverageFundV1_Implementation_0_6_0_rc1",
      execute: {
        methodName: "initCoverageFundV1",
        args: [riverDeployment.address],
      },
    },
  });

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("CoverageFund", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
