import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from '../ts-utils/helpers/index';

const func: DeployFunction = async function ({ deployments, getNamedAccounts }: HardhatRuntimeEnvironment) {
  logStep(__filename);

  const { 
    deployer, 
    proxyAdministrator,
    alluvialTreasury,
  } = await getNamedAccounts();

  const escrowDeployment = await deployments.deploy("EscrowImplementation", {
    contract: "Escrow",
    from: deployer,
    log: true,
  });

  await deployments.deploy("TLC", {
    contract: "TLCV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initTLCV1",
        args: [alluvialTreasury,escrowDeployment.address],
      },
    },
  });

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("TLC", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
