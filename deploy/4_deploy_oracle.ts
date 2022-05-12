import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getContractAddress } from 'ethers/lib/utils';

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
}: HardhatRuntimeEnvironment) {
  logStep();

  const { deployer, proxyAdministrator, systemAdministrator } =
    await getNamedAccounts();
  const riverDeployment = await deployments.get("RiverV1");
  const signer = await ethers.getSigner(deployer);

  const txCount = await signer.getTransactionCount();

  const futureOracleAddress = getContractAddress({
	  from: deployer,
	  nonce: txCount + 2 // proxy is in 3 txs
  });

  const oracleArtifact = await deployments.getArtifact("OracleV1")
  const oracleInterface = new ethers.utils.Interface(oracleArtifact.abi);

  const firewallDeployment = await deployments.deploy("Firewall", {
    from: deployer,
    log: true,
	args: [
		systemAdministrator,
		proxyAdministrator,
    futureOracleAddress,
		[
      oracleInterface.getSighash("addMember"),
      oracleInterface.getSighash("removeMember"),
      oracleInterface.getSighash("setQuorum"),
      oracleInterface.getSighash("setBeaconSpec"),
      oracleInterface.getSighash("setBeaconBounds"),
		]
	]
  });

  const oracleDeployment = await deployments.deploy("OracleV1", {
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initOracleV1",
        args: [
          riverDeployment.address,
          firewallDeployment.address,
          225,
          32,
          12,
          1606824023,
          1000,
          500,
        ],
      },
    },
  });

  if (oracleDeployment.address !== futureOracleAddress) {
	  throw new Error(`Invalid future address computation ${futureOracleAddress} != ${riverDeployment.address}`)
  }
  logStepEnd();
};
export default func;
