import { getContractAddress } from "ethers/lib/utils";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const logStep = () => {
  console.log(`=== ${__filename} START`);
  console.log();
};

const logStepEnd = () => {
  console.log();
  console.log(`=== ${__filename} END`);
};

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  logStep();

  const { deployer, proxyAdministrator, systemAdministrator, treasury } = await getNamedAccounts();

  let depositContract = (await getNamedAccounts()).depositContract;

  const withdrawDeployment = await deployments.get("WithdrawV1");
  const WithdrawContract = await ethers.getContractAt("WithdrawV1", withdrawDeployment.address);
  const withdrawalCredentials = await WithdrawContract.getCredentials();

  if (["mockedGoerli"].includes(network.name)) {
    console.log("Mocked Deposit Contract mode: ON");
    await deployments.deploy("DepositContractMock", {
      from: deployer,
      log: true,
      args: [treasury],
    });
    const mockedDepositContractDeployment = await deployments.get("DepositContractMock");
    depositContract = mockedDepositContractDeployment.address;
  }

  const signer = await ethers.getSigner(deployer);

  const txCount = await signer.getTransactionCount();

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

  const riverFirewallDeployment = await deployments.deploy("Firewall", {
    from: deployer,
    log: true,
    args: [
      systemAdministrator,
      systemAdministrator,
      futureRiverAddress,
      [
        riverInterface.getSighash("setOperatorStatus"),
        riverInterface.getSighash("setOperatorStoppedValidatorCount"),
        riverInterface.getSighash("setOperatorLimit"),
        riverInterface.getSighash("depositToConsensusLayer"),
        riverInterface.getSighash("setOracle"),
      ],
    ],
  });

  const allowlistDeployment = await deployments.get("AllowlistV1");

  const riverDeployment = await deployments.deploy("RiverV1", {
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initRiverV1",
        args: [
          depositContract,
          withdrawalCredentials,
          futureOracleAddress,
          riverFirewallDeployment.address,
          allowlistDeployment.address,
          treasury,
          500,
          50000,
        ],
      },
    },
  });

  const oracleArtifact = await deployments.getArtifact("OracleV1");
  const oracleInterface = new ethers.utils.Interface(oracleArtifact.abi);

  const oracleFirewallDeployment = await deployments.deploy("Firewall", {
    from: deployer,
    log: true,
    args: [
      systemAdministrator,
      systemAdministrator,
      futureOracleAddress,
      [
        oracleInterface.getSighash("addMember"),
        oracleInterface.getSighash("removeMember"),
        oracleInterface.getSighash("setQuorum"),
        oracleInterface.getSighash("setBeaconSpec"),
        oracleInterface.getSighash("setBeaconBounds"),
      ],
    ],
  });

  const oracleDeployment = await deployments.deploy("OracleV1", {
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initOracleV1",
        args: [riverDeployment.address, oracleFirewallDeployment.address, 225, 32, 12, 1606824023, 1000, 500],
      },
    },
  });

  if (riverDeployment.address !== futureRiverAddress) {
    throw new Error(`Invalid future river address computation ${futureRiverAddress} != ${riverDeployment.address}`);
  }

  if (oracleDeployment.address !== futureOracleAddress) {
    throw new Error(`Invalid future oracle address computation ${futureRiverAddress} != ${riverDeployment.address}`);
  }

  const riverInstance = new ethers.Contract(riverDeployment.address, riverDeployment.abi, ethers.provider);

  if ((await riverInstance.getOracle()).toLowerCase() !== oracleDeployment.address.toLowerCase()) {
    throw new Error(`Invalid oracle address provided by River`);
  }

  const oracleInstance = new ethers.Contract(oracleDeployment.address, oracleDeployment.abi, ethers.provider);

  if ((await oracleInstance.getRiver()).toLowerCase() !== riverDeployment.address.toLowerCase()) {
    throw new Error(`Invalid river address provided by Oracle`);
  }

  logStepEnd();
};
export default func;
