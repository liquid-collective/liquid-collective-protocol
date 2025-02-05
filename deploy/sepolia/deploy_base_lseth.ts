import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";
import { ethers } from "hardhat";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, network }: HardhatRuntimeEnvironment) {
  if (!["sepolia", "baseSepolia", "hardhat", "local", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for sepolia deployment");
  }
  const { deployer, proxyAdministrator, baseTokenAdmin } = await getNamedAccounts();

  const deployResult = await deployments.deploy("LsETH_Base", {
    contract: "BurnMintERC20", // "CustomCrossChainToken"
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "BurnMintERC20",
      execute: {
        methodName: "initialize",
        args: ["Liquid Staked ETH", "bsLsETH", baseTokenAdmin],
      },
    },
    gasLimit: 5000000,
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
func.tags = ["deploy_base"];
export default func;
