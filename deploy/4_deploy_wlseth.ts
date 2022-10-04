import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from '../ts-utils/helpers/index';

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  const { deployer, proxyAdministrator } = await getNamedAccounts();

  const riverDeployment = await deployments.get("River");

  await deployments.deploy("WLSETH", {
    contract: "WLSETHV1",
    from: deployer,
    log: true,
    proxy: {
      implementationName: "WLSETHV1_Implementation",
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initWLSETHV1",
        args: [riverDeployment.address],
      },
    },
  });

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, getNamedAccounts }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("WLSETH", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
