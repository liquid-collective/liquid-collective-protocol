import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

const implementationVersion = "1_2_1";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, network }: HardhatRuntimeEnvironment) {
  if (!["hardhat", "local", "tenderly", "hoodi", "devHoodi"].includes(network.name)) {
    throw new Error("Invalid network for hoodi deployment");
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
      implementationName: `CoverageFundV1_Implementation_${implementationVersion}`,
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

func.tags = ["all", "coverageFund"];

export default func;
