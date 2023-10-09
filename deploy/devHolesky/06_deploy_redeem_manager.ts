import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, network }: HardhatRuntimeEnvironment) {
  if (!["devHolesky", "hardhat","local", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for devGoerli deployment");
  }
  const { deployer, proxyAdministrator } = await getNamedAccounts();

  const riverDeployment = await deployments.get("River");

  const redeemManagerDeployment = await deployments.deploy("RedeemManager", {
    contract: "RedeemManagerV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "RedeemManagerV1_Implementation_1_1_0",
      execute: {
        methodName: "initializeRedeemManagerV1",
        args: [riverDeployment.address],
      },
    },
  });

  await verify("TUPProxy", redeemManagerDeployment.address, []);
  await verify("RedeemManagerV1", redeemManagerDeployment.implementation, []);

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("RedeemManager", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
