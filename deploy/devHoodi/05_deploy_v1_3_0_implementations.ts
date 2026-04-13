import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

const version = "1_3_0";

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  if (!["hardhat", "local", "tenderly", "hoodi", "devHoodi", "tenderly", "kurtosis"].includes(network.name)) {
    throw new Error("Invalid network for devHoodi deployment");
  }

  const { deployer } = await getNamedAccounts();

  // Fund deployer on Tenderly virtual testnet
  if (network.name === "tenderly") {
    await network.provider.request({
      method: "tenderly_setBalance",
      params: [deployer, "0x56BC75E2D63100000"], // 100 ETH
    });
  }

  const allowlistDeployment = await deployments.deploy(`AllowlistV1_Implementation_${version}`, {
    contract: "AllowlistV1",
    from: deployer,
    log: true,
  });
  await verify("AllowlistV1", allowlistDeployment.address, []);

  const coverageFundDeployment = await deployments.deploy(`CoverageFundV1_Implementation_${version}`, {
    contract: "CoverageFundV1",
    from: deployer,
    log: true,
  });
  await verify("CoverageFundV1", coverageFundDeployment.address, []);

  const elFeeRecipientDeployment = await deployments.deploy(`ELFeeRecipientV1_Implementation_${version}`, {
    contract: "ELFeeRecipientV1",
    from: deployer,
    log: true,
  });
  await verify("ELFeeRecipientV1", elFeeRecipientDeployment.address, []);

  const operatorsRegistryDeployment = await deployments.deploy(`OperatorsRegistryV1_Implementation_${version}`, {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
  });
  await verify("OperatorsRegistryV1", operatorsRegistryDeployment.address, []);

  const oracleDeployment = await deployments.deploy(`OracleV1_Implementation_${version}`, {
    contract: "OracleV1",
    from: deployer,
    log: true,
  });
  await verify("OracleV1", oracleDeployment.address, []);

  const redeemManagerDeployment = await deployments.deploy(`RedeemManagerV1_Implementation_${version}`, {
    contract: "RedeemManagerV1",
    from: deployer,
    log: true,
  });
  await verify("RedeemManagerV1", redeemManagerDeployment.address, []);

  const riverDeployment = await deployments.deploy(`RiverV1_Implementation_${version}`, {
    contract: "RiverV1",
    from: deployer,
    log: true,
  });
  await verify("RiverV1", riverDeployment.address, []);

  const withdrawDeployment = await deployments.deploy(`WithdrawV1_Implementation_${version}`, {
    contract: "WithdrawV1",
    from: deployer,
    log: true,
  });
  await verify("WithdrawV1", withdrawDeployment.address, []);

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
    (await isDeployed(`AllowlistV1_Implementation_${version}`, deployments, __filename)) &&
    (await isDeployed(`CoverageFundV1_Implementation_${version}`, deployments, __filename)) &&
    (await isDeployed(`ELFeeRecipientV1_Implementation_${version}`, deployments, __filename)) &&
    (await isDeployed(`OperatorsRegistryV1_Implementation_${version}`, deployments, __filename)) &&
    (await isDeployed(`OracleV1_Implementation_${version}`, deployments, __filename)) &&
    (await isDeployed(`RedeemManagerV1_Implementation_${version}`, deployments, __filename)) &&
    (await isDeployed(`RiverV1_Implementation_${version}`, deployments, __filename)) &&
    (await isDeployed(`WithdrawV1_Implementation_${version}`, deployments, __filename));
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

func.tags = ["upgrade_v1_3_0_implementations"];

export default func;
