import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";

// this upgrade occurs after the 11/22 spearbit audit changes
const func: DeployFunction = async function ({ deployments, getNamedAccounts }: HardhatRuntimeEnvironment) {
  const { deployer } = await getNamedAccounts();

  await deployments.deploy("AllowlistV1_Implementation_0_5_0", {
    contract: "AllowlistV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("RiverV1_Implementation_0_5_0", {
    contract: "RiverV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("TLCV1_Implementation_0_5_0", {
    contract: "TLCV1",
    from: deployer,
    log: true,
  });

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
    (await isDeployed("AllowlistV1_Implementation_0_5_0", deployments, __filename)) &&
    (await isDeployed("RiverV1_Implementation_0_5_0", deployments, __filename)) &&
    (await isDeployed("TLCV1_Implementation_0_5_0", deployments, __filename));
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
