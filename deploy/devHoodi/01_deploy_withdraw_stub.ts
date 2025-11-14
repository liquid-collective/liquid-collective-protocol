import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

const implementationVersion = "1_2_1";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, network }: HardhatRuntimeEnvironment) {
  if (!["hardhat", "local", "tenderly", "hoodi", "devHoodi", "kurtosis"].includes(network.name)) {
    throw new Error("Invalid network for hoodi deployment");
  }
  const { deployer, proxyAdministrator } = await getNamedAccounts();

  const deployResult = await deployments.deploy("Withdraw", {
    contract: "WithdrawV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: `WithdrawV1_Implementation_${implementationVersion}`,
    },
  });

  await verify("TUPProxy", deployResult.address, deployResult.args, deployResult.libraries);
  await verify("WithdrawV1", deployResult.implementation, []);

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

func.tags = ["all", "withdraw"];

export default func;
