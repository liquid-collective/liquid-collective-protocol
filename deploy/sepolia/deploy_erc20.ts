import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, network }: HardhatRuntimeEnvironment) {
  if (!["sepolia", "hardhat", "local", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for holesky deployment");
  }
  const { deployer, proxyAdministrator } = await getNamedAccounts();

  const deployResult = await deployments.deploy("LsETH_Base", {
    contract: "BurnMintERC20",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "BurnMintERC20",
    },
  });

  await verify("TUPProxy", deployResult.address, deployResult.args, deployResult.libraries);
  await verify("BurnMintERC20", deployResult.implementation, []);

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("LsETH_Base", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
