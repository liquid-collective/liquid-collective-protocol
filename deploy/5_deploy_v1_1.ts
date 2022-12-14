import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../ts-utils/helpers/index";

// This migration brings the post audit modifications to the goerli and mockedGoerli deployments
const func: DeployFunction = async function ({ deployments, getNamedAccounts }: HardhatRuntimeEnvironment) {
  const { deployer } = await getNamedAccounts();

  await deployments.deploy("RiverV1_Implementation_0_4_4", {
    contract: "RiverV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("OperatorsRegistryV1_Implementation_0_4_0", {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("OracleV1_Implementation_0_4_0", {
    contract: "OracleV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("WLSETHV1_Implementation_0_4_0", {
    contract: "WLSETHV1",
    from: deployer,
    log: true,
  });

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, network }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
    !["mockedGoerli", "goerli", "local", "hardhat"].includes(network.name) ||
    ((await isDeployed("RiverV1_Implementation_0_4_0", deployments, __filename)) &&
      (await isDeployed("OperatorsRegistryV1_Implementation_0_4_0", deployments, __filename)) &&
      (await isDeployed("OracleV1_Implementation_0_4_0", deployments, __filename)) &&
      (await isDeployed("WLSETHV1_Implementation_0_4_0", deployments, __filename)));
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
