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

  const { deployer, proxyAdministrator, systemAdministrator } =
    await getNamedAccounts();
  const riverDeployment = await deployments.get("RiverV1");

  await deployments.deploy("OracleV1", {
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "oracleInitializeV1",
        args: [
          riverDeployment.address,
          systemAdministrator,
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

  logStepEnd();
};
export default func;
