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

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  logStep();

  const { deployer, proxyAdministrator } = await getNamedAccounts();

  const riverDeployment = await deployments.get("RiverV1");

  await deployments.deploy("WLSETHV1", {
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initWLSETHV1",
        args: [riverDeployment.address],
      },
    },
  });

  logStepEnd();
};
export default func;
