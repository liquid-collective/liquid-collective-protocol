import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const logStep = () => {
  console.log(`=== ${__filename} START`);
  console.log();
};

const logStepEnd = () => {
  console.log();
  console.log(`=== ${__filename} END`);
};

const func: DeployFunction = async function ({ deployments, getNamedAccounts }: HardhatRuntimeEnvironment) {
  logStep();

  const { 
    deployer, 
    proxyAdministrator,
    alluvialTreasury,
 } = await getNamedAccounts();

  await deployments.deploy("TLC", {
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initTLCV1",
        args: [
            alluvialTreasury,
        ],
      },
    },
  });

  logStepEnd();
};
export default func;
