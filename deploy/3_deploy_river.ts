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

  const oracleDeployment = await deployments.get("OracleV1");
  // const withdrawDeployment = await deployments.get("WithdrawV1");

  await deployments.deploy("RiverV1", {
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "riverInitializeV1",
        args: [
          depositContract,
          `0x${"0".repeat(64)}`,
          oracleDeployment.address,
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
