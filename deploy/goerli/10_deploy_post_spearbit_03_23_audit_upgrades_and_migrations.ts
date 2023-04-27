import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { TUPPROXY_VERSION_SLOT } from "../../ts-utils/helpers/constants";
import { getContractAddress } from "ethers/lib/utils";

const func: DeployFunction = async function ({ deployments, network, getNamedAccounts, ethers }: HardhatRuntimeEnvironment) {
  if (!["goerli", "hardhat"].includes(network.name)) {
    throw new Error("Invalid network for devGoerli deployment");
  }

  const { deployer, executor, governor } = await getNamedAccounts();
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
    args: [governor, executor, futureRedeemManagerAddress, [proxyInterface.getSighash("pause()")]],
  });

  const redeemManagerDeployment = await deployments.deploy("RedeemManager", {
    contract: "RedeemManagerV1",
    from: deployer,
    log: true,
    proxy: {
      owner: redeemManagerProxyFirewall.address,
      proxyContract: "TUPProxy",
      implementationName: "RedeemManagerV1_Implementation_0_6_0_rc2",
      execute: {
        methodName: "initializeRedeemManagerV1",
        args: [riverDeployment.address],
      },
    },
  });

  if (redeemManagerDeployment.address !== futureRedeemManagerAddress) {
    throw new Error(`Invalid future redeem manager address computation ${futureRedeemManagerAddress} != ${redeemManagerDeployment.address}`);
  }

  await deployments.deploy("ELFeeRecipientV1_Implementation_0_6_0_rc2", {
    contract: "ELFeeRecipientV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("OperatorsRegistryV1_Implementation_0_6_0_rc2", {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("OracleV1_Implementation_0_6_0_rc2", {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("RiverV1_Implementation_0_6_0_rc2", {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("TLCV1_Implementation_0_6_0_rc2", {
    contract: "TLCV1",
    from: deployer,
    log: true,
  });

  await deployments.deploy("WithdrawV1_Implementation_0_6_0_rc2", {
    contract: "WithdrawV1",
    from: deployer,
    log: true,
  });

  // migration and upgrade steps
  // 1. upgrade WithdrawContract + WithdrawContract.initializeWithdrawV1(riverDeployment.address)
  // 2. upgrade OperatorsRegistry + OperatorsRegistryContract.initOperatorsRegistryV1_1()
  // 3. upgrade OracleContract + OracleContract.initOracleV1_1()
  // 4. upgrade RiverContract + RiverContract.initRiverV1_1(
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
  // 5. upgrade ELFeeRecipientContract
  // 6. upgrade TLCContract
  // 7. call OperatorsRegistryContract.forceFundedValidatorKeysEventEmission(x) several time until it reverts

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, ethers }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = !(
    BigInt(await ethers.provider.getStorageAt((await deployments.get("River")).address, TUPPROXY_VERSION_SLOT)) ===
    BigInt(1) &&
    BigInt(await ethers.provider.getStorageAt((await deployments.get("Withdraw")).address, TUPPROXY_VERSION_SLOT)) ===
    BigInt(0) &&
    BigInt(
      await ethers.provider.getStorageAt((await deployments.get("OperatorsRegistry")).address, TUPPROXY_VERSION_SLOT)
    ) === BigInt(1) &&
    BigInt(await ethers.provider.getStorageAt((await deployments.get("Oracle")).address, TUPPROXY_VERSION_SLOT)) ===
    BigInt(1)
  );
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
