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
}: HardhatRuntimeEnvironment) {
  logStep();

  const {
    deployer,
    depositContract,
    proxyAdministrator,
    systemAdministrator,
    treasury,
  } = await getNamedAccounts();

  const withdrawDeployment = await deployments.get("WithdrawV1");
  const WithdrawContract = await ethers.getContractAt("WithdrawV1", withdrawDeployment.address);
  const withdrawalCredentials = await WithdrawContract.getCredentials();

  await deployments.deploy("RiverV1", {
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
          systemAdministrator,
          systemAdministrator,
          treasury,
          500,
          50000,
        ],
      },
    },
  });

  logStepEnd();
};
export default func;
