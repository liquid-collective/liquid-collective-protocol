import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { TUPPROXY_VERSION_SLOT } from "../../ts-utils/helpers/constants";
import { verify } from "../../scripts/helpers";

const func: DeployFunction = async function ({ deployments, network, getNamedAccounts }: HardhatRuntimeEnvironment) {
  if (!["devHolesky", "hardhat", "local", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for devGoerli deployment");
  }

  const { deployer } = await getNamedAccounts();

  const riverImplementationDeployment = await deployments.deploy("River1_Implementation_0_6_0_rc2", {
    contract: "RiverV1",
    from: deployer,
    log: true,
  });

  await verify("RiverV1", riverImplementationDeployment.address, []);

  const redeemManagerDeployment = await deployments.deploy("RedeemManagerV1_Implementation_0_6_0_rc2", {
    contract: "RedeemManagerV1",
    from: deployer,
    log: true,
  });

  await verify("RedeemManagerV1", redeemManagerDeployment.address, []);

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
    (await isDeployed("RiverV1_Implementation_0_6_0_rc2", deployments, __filename)) &&
    (await isDeployed("RedeemManagerV1_Implementation_0_6_0_rc2", deployments, __filename));
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
