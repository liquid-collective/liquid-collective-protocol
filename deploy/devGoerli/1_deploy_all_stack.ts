import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { isDeployed, logStep, logStepEnd } from '../../ts-utils/helpers/index';
import { getContractAddress } from "ethers/lib/utils";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, ethers }: HardhatRuntimeEnvironment) {
	const { deployer, proxyAdministrator, governor, depositContract, collector } = await getNamedAccounts();

	let genesisTimestamp = 1616508000;
	let grossFee = 1500;


	const withdrawDeployment = await deployments.deploy("Withdraw", {
		contract: "WithdrawV1",
		from: deployer,
		log: true,
		proxy: {
			owner: proxyAdministrator,
			proxyContract: "TUPProxy",
			implementationName: "WithdrawV1_Implementation_0_5_0",
		},
	});

	const WithdrawContract = await ethers.getContractAt("WithdrawV1", withdrawDeployment.address);
	const withdrawalCredentials = await WithdrawContract.getCredentials();

	const allowlistDeployment = await deployments.deploy("Allowlist", {
		contract: "AllowlistV1",
		from: deployer,
		log: true,
		proxy: {
			owner: proxyAdministrator,
			proxyContract: "TUPProxy",
			implementationName: "AllowlistV1_Implementation_0_5_0",
			execute: {
				methodName: "initAllowlistV1",
				args: [governor, governor],
			},
		},
	});

	const signer = await ethers.getSigner(deployer);

	const txCount = await signer.getTransactionCount();

	const futureELFeeRecipientAddress = getContractAddress({
		from: deployer,
		nonce: txCount + 8, // proxy is in 8 txs
	});

	const futureOperatorsRegistryAddress = getContractAddress({
		from: deployer,
		nonce: txCount + 6, // proxy is in 8 txs
	});

	const futureOracleAddress = getContractAddress({
		from: deployer,
		nonce: txCount + 4, // proxy is in 6 txs
	});



	const riverDeployment = await deployments.deploy("River", {
		contract: "RiverV1",
		from: deployer,
		log: true,
		proxy: {
			owner: proxyAdministrator,
			proxyContract: "TUPProxy",
			implementationName: "RiverV1_Implementation_0_5_0",
			execute: {
				methodName: "initRiverV1",
				args: [
					depositContract,
					futureELFeeRecipientAddress,
					withdrawalCredentials,
					futureOracleAddress,
					governor,
					allowlistDeployment.address,
					futureOperatorsRegistryAddress,
					collector,
					grossFee,
				],
			},
		},
	});

	const oracleDeployment = await deployments.deploy("Oracle", {
		contract: "OracleV1",
		from: deployer,
		log: true,
		proxy: {
			owner: proxyAdministrator,
			proxyContract: "TUPProxy",
			implementationName: "OracleV1_Implementation_0_5_0",
			execute: {
				methodName: "initOracleV1",
				args: [riverDeployment.address, governor, 225, 32, 12, genesisTimestamp, 1000, 500],
			},
		},
	});

	const operatorsRegistryDeployment = await deployments.deploy("OperatorsRegistry", {
		contract: "OperatorsRegistryV1",
		from: deployer,
		log: true,
		proxy: {
			owner: proxyAdministrator,
			proxyContract: "TUPProxy",
			implementationName: "OperatorsRegistryV1_Implementation_0_5_0",
			execute: {
				methodName: "initOperatorsRegistryV1",
				args: [governor, riverDeployment.address],
			},
		},
	});

	const elFeeRecipientDeployment = await deployments.deploy("ELFeeRecipient", {
		contract: "ELFeeRecipientV1",
		from: deployer,
		log: true,
		proxy: {
			implementationName: "ELFeeRecipientV1_Implementation_0_5_0",
			owner: proxyAdministrator,
			proxyContract: "TUPProxy",
			execute: {
				methodName: "initELFeeRecipientV1",
				args: [riverDeployment.address],
			},
		},
	});

	await deployments.deploy("CoverageFund", {
		contract: "CoverageFundV1",
		from: deployer,
		log: true,
		proxy: {
			owner: proxyAdministrator,
			proxyContract: "TUPProxy",
			implementationName: "CoverageFundV1_Implementation_0_5_0",
			execute: {
				methodName: "initCoverageFundV1",
				args: [riverDeployment.address],
			},
		},
	});

	const redeemManagerDeployment = await deployments.deploy("RedeemManager", {
		contract: "RedeemManagerV1",
		from: deployer,
		log: true,
		proxy: {
			owner: proxyAdministrator,
			proxyContract: "TUPProxy",
			implementationName: "RedeemManagerV1_Implementation_0_5_0",
			execute: {
				methodName: "initializeRedeemManagerV1",
				args: [riverDeployment.address],
			},
		},
	});



	{
		const RiverContract = await ethers.getContractAt("RiverV1", riverDeployment.address);
		// we do this only on testnet, on mainnet it will be done via atomic contract upgrades
		const tx = await RiverContract.initRiverV1_1(redeemManagerDeployment.address, 225, 32, 12, genesisTimestamp, 4, 1000, 500, "3200000000000000000000", "1000");
		console.log("river.initRiverV1_1", tx.hash);
	}

	logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
	logStep(__filename);
	const shouldSkip = await isDeployed("Withdraw", deployments, __filename);
	if (shouldSkip) {
		console.log("Skipped");
		logStepEnd(__filename);
	}
	return shouldSkip;
};

export default func;

