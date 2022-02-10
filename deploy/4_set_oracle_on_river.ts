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

const administratorCallHint = (administrator: string, contractAddress: string, method: string, args: any[]) => {
    console.log(`============================================================`)
    console.log()
    console.log(`Administrator action required`)
    console.log(`From=${administrator}`)
    console.log(`To=${contractAddress}`)
    console.log(`Method=${method}`)
    for (let idx = 0; idx < args.length; ++idx) {
      console.log(`Arg${idx + 1}=${args[idx].toString()}`)
    }
    console.log()
    console.log(`============================================================`)

}

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  artifacts,
}: HardhatRuntimeEnvironment) {
  logStep();

  const riverDeployment = await deployments.get("RiverV1");
  const oracleDeployment = await deployments.get("OracleV1");

  const river = await ethers.getContractAt("RiverV1", riverDeployment.address);
  let oracleAddress = await river.getOracle();
  if (oracleAddress.toLowerCase() !== oracleDeployment.address.toLowerCase()) {
    administratorCallHint(await river.getAdministrator(), river.address, 'setOracle(address)', [oracleDeployment.address])
  }
  let round = 0;
  do {
    oracleAddress = await river.getOracle();
    process.stdout.write('.');
    await new Promise(resolve => setTimeout(resolve, 1000));
    ++round;
    if (round % 60 === 0 && round > 0) {
      process.stdout.write('\n')
    }
  } while (oracleAddress.toLowerCase() !== oracleDeployment.address.toLowerCase());

  logStepEnd();
};
export default func;
