import { getContractAddress } from "ethers/lib/utils";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  let genesisTimestamp = 0;
  switch (network.name) {
    case "goerli":
    case "mockedGoerli": {
      genesisTimestamp = 1616508000;
      break;
    }
    case "mainnet": {
      genesisTimestamp = 1606824023;
      break;
    }
  }

  let grossFee = 0;
  switch (network.name) {
    case "goerli":
    case "mockedGoerli": {
      grossFee = 1250;
      break;
    }
    case "mainnet": {
      grossFee = 1500;
      break;
    }
  }

  const { deployer, governor, executor, proxyAdministrator, collector } = await getNamedAccounts();

  let depositContract = (await getNamedAccounts()).depositContract;

  const withdrawDeployment = await deployments.get("Withdraw");
  const WithdrawContract = await ethers.getContractAt("WithdrawV1", withdrawDeployment.address);
  const withdrawalCredentials = await WithdrawContract.getCredentials();

  if (["mockedGoerli"].includes(network.name)) {
    console.log("Mocked Deposit Contract mode: ON");
    await deployments.deploy("DepositContractMock", {
      from: deployer,
      log: true,
      args: [collector],
    });
    const mockedDepositContractDeployment = await deployments.get("DepositContractMock");
    depositContract = mockedDepositContractDeployment.address;
  }

  const signer = await ethers.getSigner(deployer);

  const txCount = await signer.getTransactionCount();

  const futureELFeeRecipientAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 10, // proxy is in 8 txs
  });

  const futureOperatorsRegistryAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 8, // proxy is in 8 txs
  });

  const futureOracleAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 5, // proxy is in 6 txs
  });

  const futureRiverAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 2, // proxy is in 3 txs
  });

  const riverArtifact = await deployments.getArtifact("RiverV1");
  const riverInterface = new ethers.utils.Interface(riverArtifact.abi);

  const riverFirewallDeployment = await deployments.deploy("RiverFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, futureRiverAddress, [riverInterface.getSighash("depositToConsensusLayer")]],
  });

  const allowlistDeployment = await deployments.get("Allowlist");

  const riverDeployment = await deployments.deploy("River", {
    contract: "RiverV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "RiverV1_Implementation_0_2_2",
      execute: {
        methodName: "initRiverV1",
        args: [
          depositContract,
          futureELFeeRecipientAddress,
          withdrawalCredentials,
          futureOracleAddress,
          riverFirewallDeployment.address,
          allowlistDeployment.address,
          futureOperatorsRegistryAddress,
          collector,
          grossFee,
        ],
      },
    },
  });

  const oracleArtifact = await deployments.getArtifact("OracleV1");
  const oracleInterface = new ethers.utils.Interface(oracleArtifact.abi);

  const oracleFirewallDeployment = await deployments.deploy("OracleFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, futureOracleAddress, [oracleInterface.getSighash("removeMember")]],
  });

  const oracleDeployment = await deployments.deploy("Oracle", {
    contract: "OracleV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "OracleV1_Implementation_0_2_2",
      execute: {
        methodName: "initOracleV1",
        args: [riverDeployment.address, oracleFirewallDeployment.address, 225, 32, 12, genesisTimestamp, 1000, 500],
      },
    },
  });

  const operatorsRegistryArtifact = await deployments.getArtifact("OperatorsRegistryV1");
  const operatorsRegsitryInterface = new ethers.utils.Interface(operatorsRegistryArtifact.abi);

  const operatorsRegistryFirewallDeployment = await deployments.deploy("OperatorsRegistryFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [
      governor,
      executor,
      futureOperatorsRegistryAddress,
      [
        operatorsRegsitryInterface.getSighash("setOperatorStatus"),
        operatorsRegsitryInterface.getSighash("setOperatorName"),
        operatorsRegsitryInterface.getSighash("setOperatorStoppedValidatorCount"),
        operatorsRegsitryInterface.getSighash("setOperatorLimits"),
      ],
    ],
  });

  const operatorsRegistryDeployment = await deployments.deploy("OperatorsRegistry", {
    contract: "OperatorsRegistryV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "OperatorsRegistryV1_Implementation_0_2_2",
      execute: {
        methodName: "initOperatorsRegistryV1",
        args: [operatorsRegistryFirewallDeployment.address, futureRiverAddress],
      },
    },
  });

  const elFeeRecipientDeployment = await deployments.deploy("ELFeeRecipient", {
    contract: "ELFeeRecipientV1",
    from: deployer,
    log: true,
    proxy: {
      implementationName: "ELFeeRecipientV1_Implementation_0_2_2",
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initELFeeRecipientV1",
        args: [riverDeployment.address],
      },
    },
  });

  if (riverDeployment.address !== futureRiverAddress) {
    throw new Error(`Invalid future river address computation ${futureRiverAddress} != ${riverDeployment.address}`);
  }

  if (oracleDeployment.address !== futureOracleAddress) {
    throw new Error(`Invalid future oracle address computation ${futureRiverAddress} != ${riverDeployment.address}`);
  }

  if (elFeeRecipientDeployment.address !== futureELFeeRecipientAddress) {
    throw new Error(
      `Invalid future EL Fee Recipient address computation ${futureELFeeRecipientAddress} != ${elFeeRecipientDeployment.address}`
    );
  }

  if (operatorsRegistryDeployment.address !== futureOperatorsRegistryAddress) {
    throw new Error(
      `Invalid future Operators Registry address computation ${futureOperatorsRegistryAddress} != ${operatorsRegistryDeployment.address}`
    );
  }

  const riverInstance = new ethers.Contract(riverDeployment.address, riverDeployment.abi, ethers.provider);

  if ((await riverInstance.getOracle()).toLowerCase() !== oracleDeployment.address.toLowerCase()) {
    throw new Error(`Invalid oracle address provided by River`);
  }

  const oracleInstance = new ethers.Contract(oracleDeployment.address, oracleDeployment.abi, ethers.provider);

  if ((await oracleInstance.getRiver()).toLowerCase() !== riverDeployment.address.toLowerCase()) {
    throw new Error(`Invalid river address provided by Oracle`);
  }

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
    (await isDeployed("River", deployments, __filename)) &&
    (await isDeployed("Oracle", deployments, __filename)) &&
    (await isDeployed("OperatorsRegistry", deployments, __filename)) &&
    (await isDeployed("ELFeeRecipient", deployments, __filename));
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
