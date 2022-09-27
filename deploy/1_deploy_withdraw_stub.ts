import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";

const logStep = () => {
  console.log(`=== ${__filename} START`);
  console.log();
};

const logStepEnd = () => {
  console.log();
  console.log(`=== ${__filename} END`);
};

const func: DeployFunction = async function ({ deployments, getNamedAccounts }: HardhatRuntimeEnvironment) {
  const { deployer, proxyAdministrator } = await getNamedAccounts();

  await deployments.deploy("Withdraw", {
    contract: "WithdrawV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "WithdrawV1_Implementation",
    },
  });

  logStepEnd();
};

func.skip = async function ({ deployments, getNamedAccounts }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep();
  try {
    await deployments.get("Withdraw_Proxy");
    console.log("Skipping");
    logStepEnd();
    return true;
  } catch (e) {
    return false;
  }
};

export default func;
