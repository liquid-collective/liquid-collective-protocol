import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";
import { ethers } from "hardhat";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, network }: HardhatRuntimeEnvironment) {
  if (!["sepolia", "hardhat", "local", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for holesky deployment");
  }
  const { deployer, proxyAdministrator } = await getNamedAccounts();
  console.log("deployer", deployer);
  
  const deployResult = await deployments.deploy("LsETH_Base", {
    contract: "TUPProxy",// "CustomCrossChainToken"
    from: deployer,
    log: true,
    args: ["0x6c509ebd10125576E4828Bd247a40B351a790f2f","0x726Da59a3cF0966BeF383d3A00Ac002a66Fece30","0x4cd88b760000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000114c6971756964205374616b65642045544800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000054c73455448000000000000000000000000000000000000000000000000000000"],
    gasLimit: 5000000,
  });

  await verify("TUPProxy", deployResult.address, deployResult.args, deployResult.libraries);
  // await verify("BurnMintERC20", deployResult.implementation, []);

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
