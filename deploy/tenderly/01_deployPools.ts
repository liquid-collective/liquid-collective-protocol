import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";
import { PoolDeployer__factory } from "../../typechain";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, ethers }: HardhatRuntimeEnvironment) {
  const { deployer, proxyAdministrator, governor, executor } = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  const poolDeployment = await deployments.deploy("PoolDeployer", {
    contract: "PoolDeployer",
    from: deployer,
    log: true,
    args: [
      deployer,
      "0xCD859343d6C95E3791B389b63225794DB98e7F6C",
      "0xCfa8cf872f0B8cE15C175a8eB13688D5c69E9CEe",
      "0x48D93d8C45Fb25125F13cdd40529BbeaA97A6565",
      "0x485ade5B7f66ECcaD4583862bc5c2Aa838720aA0",
      "0x99Dd9F8D3a62cb416f6ef5ABBC90185c4162f8d0",
      "0x108A04f7A181A1e0A58Bdb1772707aEe88294e13",
      "0x6B747258A0E926De1F5C2a54Fe92514706Cce2D4",
      "0x423CE5282c460EED5FE0786B4D47d2c2a4Ef3721",
      "0xF1b958564edF538dDa1302D3D81eB58eE204B87F",
    ],
  });

//   const poolDeployer = PoolDeployer__factory.connect(poolDeployment.address, signer);
//   await poolDeployer.deployPool(governor, proxyAdministrator, executor);
  const pD = new ethers.Contract(poolDeployment.address, poolDeployment.abi, signer)
  await pD.deployPool(governor, proxyAdministrator, executor)
  await verify("PoolDeployer", poolDeployment.address, poolDeployment.args);
  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("PoolDeployer", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
