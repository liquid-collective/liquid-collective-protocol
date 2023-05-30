import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { getContractAddress } from "ethers/lib/utils";

const func: DeployFunction = async function ({ deployments, network, getNamedAccounts, ethers }: HardhatRuntimeEnvironment) {
  if (!["mainnet", "hardhat"].includes(network.name)) {
    throw new Error("Invalid network for devGoerli deployment");
  }

  const { deployer, executor, proxyAdministrator } = await getNamedAccounts();
  const riverDeployment = await deployments.get("River");
  const proxyArtifact = await deployments.getArtifact("TUPProxy");
  const proxyInterface = new ethers.utils.Interface(proxyArtifact.abi);
  const signer = await ethers.getSigner(deployer);
  const txCount = await signer.getTransactionCount();

  const futureRedeemManagerAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 2,
  });

  const redeemManagerProxyFirewall = await deployments.deploy("RedeemManagerProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, futureRedeemManagerAddress, [proxyInterface.getSighash("pause()")]],
  });

  const redeemManagerDeployment = await deployments.deploy("RedeemManager", {
    contract: "RedeemManagerV1",
    from: deployer,
    log: true,
    proxy: {
      owner: redeemManagerProxyFirewall.address,
      proxyContract: "TUPProxy",
      implementationName: "RedeemManagerV1_Implementation_0_6_0",
      execute: {
        methodName: "initializeRedeemManagerV1",
        args: [riverDeployment.address],
      },
    },
  });

  if (redeemManagerDeployment.address !== futureRedeemManagerAddress) {
    throw new Error(`Invalid future redeem manager address computation ${futureRedeemManagerAddress} != ${redeemManagerDeployment.address}`);
  }

  await deployments.deploy("ELFeeRecipientV1_Implementation_0_6_0", {
    contract: "ELFeeRecipientV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("OperatorsRegistryV1_Implementation_0_6_0", {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("OracleV1_Implementation_0_6_0", {
    contract: "OracleV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("RiverV1_Implementation_0_6_0", {
    contract: "RiverV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("WithdrawV1_Implementation_0_6_0", {
    contract: "WithdrawV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("TLCV1_Implementation_0_6_0", {
    contract: "TLCV1",
    from: deployer,
    log: true,
  });

  // migration and upgrade steps
  // 1. upgradeToAndCall WithdrawContract + WithdrawContract.initializeWithdrawV1(riverDeployment.address)
  // 2. upgradeToAndCall OperatorsRegistry + OperatorsRegistryContract.initOperatorsRegistryV1_1()
  // 3. upgradeToAndCall OracleContract + OracleContract.initOracleV1_1()
  // 4. upgradeToAndCall RiverContract + RiverContract.initRiverV1_1(
  //                              redeemManagerDeployment.address,
  //                              epochsPerFrame,
  //                              slotsPerEpoch,
  //                              secondsPerSlot,
  //                              genesisTimestamp,
  //                              epochsToAssumedFinality,
  //                              upperBound,
  //                              lowerBound,
  //                              minDailyNetCommittable,
  //                              maxDailyRelativeCommittable
  //                            );
  // 5. upgradeTo ELFeeRecipientContract
  // 6. upgradeTo TLCContract
  // 7. call OperatorsRegistryContract.forceFundedValidatorKeysEventEmission(x) several time until it reverts

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
    (await isDeployed("RedeemManagerV1_Implementation_0_6_0", deployments, __filename)) &&
    (await isDeployed("ELFeeRecipientV1_Implementation_0_6_0", deployments, __filename)) &&
    (await isDeployed("OperatorsRegistryV1_Implementation_0_6_0", deployments, __filename)) &&
    (await isDeployed("OracleV1_Implementation_0_6_0", deployments, __filename)) &&
    (await isDeployed("RiverV1_Implementation_0_6_0", deployments, __filename)) &&
    (await isDeployed("WithdrawV1_Implementation_0_6_0", deployments, __filename)) &&
    (await isDeployed("TLCV1_Implementation_0_6_0", deployments, __filename));
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
