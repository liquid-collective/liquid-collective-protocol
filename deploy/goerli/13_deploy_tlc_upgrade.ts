import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";

const func: DeployFunction = async function ({ deployments, network, getNamedAccounts }: HardhatRuntimeEnvironment) {
  if (!["goerli", "hardhat"].includes(network.name)) {
    throw new Error("Invalid network for goerli deployment");
  }

  const { deployer } = await getNamedAccounts();

  await deployments.deploy("TLCV1_Implementation_1_1_0", {
    contract: "TLCV1",
    from: deployer,
    log: true,
  });
  
  await deployments.deploy("TLC_GlobalUnlockSchedule_Migration", {
    contract: "TlcMigration",
    from: deployer,
    log: true,
  });

  // migration and upgrade steps
  // 1. upgradeToAndCall  TlcMigration + TlcMigration.migrate()
  // 2. upgradeTo         TLCV1_Implementation_1_1_0
  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
  (await isDeployed("TLCV1_Implementation_1_1_0", deployments, __filename)) &&
  (await isDeployed("TLC_GlobalUnlockSchedule_Migration", deployments, __filename))
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
