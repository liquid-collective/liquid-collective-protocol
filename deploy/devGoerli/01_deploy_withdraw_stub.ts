import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, network }: HardhatRuntimeEnvironment) {
  if (!["devGoerli", "hardhat"].includes(network.name)) {
    throw new Error("Invalid network for devGoerli deployment");
  }
  const { deployer, proxyAdministrator } = await getNamedAccounts();

  await deployments.deploy("Withdraw", {
    contract: "WithdrawV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "WithdrawV1_Implementation_0_6_0",
    },
  });

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("Withdraw", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
