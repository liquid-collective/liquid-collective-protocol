import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, network }: HardhatRuntimeEnvironment) {
  if (!["holesky", "hardhat", "local", "tenderly", "devHolesky"].includes(network.name)) {
    throw new Error("Invalid network for holesky deployment");
  }
  const { deployer, proxyAdministrator } = await getNamedAccounts();

  const riverDeployment = await deployments.get("River");

  const coverageFundDeployment = await deployments.deploy("CoverageFund", {
    contract: "CoverageFundV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "CoverageFundV1_Implementation_0_5_0",
      execute: {
        methodName: "initCoverageFundV1",
        args: [riverDeployment.address],
      },
    },
  });

  await verify(
    "TUPProxy",
    coverageFundDeployment.address,
    coverageFundDeployment.args,
    coverageFundDeployment.libraries
  );
  await verify("CoverageFundV1", coverageFundDeployment.implementation, []);

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
