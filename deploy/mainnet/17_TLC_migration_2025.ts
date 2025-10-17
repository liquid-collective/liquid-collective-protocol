import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

const func: DeployFunction = async function ({ deployments, network, getNamedAccounts }: HardhatRuntimeEnvironment) {
  if (!["mainnet", "hardhat", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for mainnet deployment");
  }

  const { deployer } = await getNamedAccounts();

  const tlcMigrationDeployment = await deployments.deploy("TLC_GlobalUnlockSchedule_Migration_2025", {
    contract: "TlcMigration",
    from: deployer,
    log: true,
  });

  await verify("TlcMigration", tlcMigrationDeployment.address, []);
  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("TLC_GlobalUnlockSchedule_Migration_2025", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
