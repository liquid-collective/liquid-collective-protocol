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

  logStepEnd();
};

func.skip = async function ({ deployments, getNamedAccounts }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep();
  try {
    await deployments.get("WLSETH_Proxy");
    console.log("Skipping");
    logStepEnd();
    return true;
  } catch (e) {
    return false;
  }
};

export default func;
