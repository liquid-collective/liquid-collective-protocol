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
  artifacts,
  network
}: HardhatRuntimeEnvironment) {
  logStep();

  const {
    deployer,
    proxyAdministrator,
    systemAdministrator,
    treasury,
  } = await getNamedAccounts();

  let depositContract = (await getNamedAccounts()).depositContract;

  const withdrawDeployment = await deployments.get("WithdrawV1");
  const WithdrawContract = await ethers.getContractAt("WithdrawV1", withdrawDeployment.address);
  const withdrawalCredentials = await WithdrawContract.getCredentials();

  if (['mockedGoerli'].includes(network.name)) {
    console.log("Mocked Deposit Contract mode: ON");
    await deployments.deploy("DepositContractMock", {
      from: deployer,
      log: true,
      args: [treasury]
    })
    const mockedDepositContractDeployment = await deployments.get("DepositContractMock");
    depositContract = mockedDepositContractDeployment.address;
  }

  const signer = await ethers.getSigner(deployer);

  const txCount = await signer.getTransactionCount();

  const futureRiverAddress = getContractAddress({
	  from: deployer,
	  nonce: txCount + 2 // proxy is in 3 txs
  });

  const riverArtifact = await deployments.getArtifact("RiverV1")
  const riverInterface = new ethers.utils.Interface(riverArtifact.abi);

  const firewallDeployment = await deployments.deploy("Firewall", {
    from: deployer,
    log: true,
	args: [
		systemAdministrator,
		proxyAdministrator,
		futureRiverAddress,
		[
      riverInterface.getSighash("setOperatorStatus"),
      riverInterface.getSighash("setOperatorStoppedValidatorCount"),
      riverInterface.getSighash("setOperatorLimit"),
      riverInterface.getSighash("depositToConsensusLayer"),
      riverInterface.getSighash("setOracle"),
		]
	]
  });

  const allowlistDeployment = await deployments.get("AllowlistV1")

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
          firewallDeployment.address,
          allowlistDeployment.address,
          treasury,
          500,
          50000,
        ],
      },
    },
  });

  if (riverDeployment.address !== futureRiverAddress) {
	  throw new Error(`Invalid future address computation ${futureRiverAddress} != ${riverDeployment.address}`)
  }

  logStepEnd();
};
export default func;
