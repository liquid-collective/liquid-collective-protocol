import { ethers } from "ethers";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";

// This migration brings the post audit modifications to the goerli and mockedGoerli deployments
const func: DeployFunction = async function ({ deployments, getNamedAccounts }: HardhatRuntimeEnvironment) {
  const { deployer, proxyAdministrator, executor } = await getNamedAccounts();

  const proxyArtifact = await deployments.getArtifact("TUPProxy");
  const proxyInterface = new ethers.utils.Interface(proxyArtifact.abi);

  const riverDeployment = await deployments.get("River");
  await deployments.deploy("RiverProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, riverDeployment.address, [proxyInterface.getSighash("pause()")]],
  });

  const oracleDeployment = await deployments.get("Oracle");
  await deployments.deploy("OracleProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, oracleDeployment.address, [proxyInterface.getSighash("pause()")]],
  });

  const operatorsRegistryDeployment = await deployments.get("OperatorsRegistry");
  await deployments.deploy("OperatorsRegistryProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, operatorsRegistryDeployment.address, [proxyInterface.getSighash("pause()")]],
  });

  const allowlistDeployment = await deployments.get("Allowlist");
  await deployments.deploy("AllowlistProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, allowlistDeployment.address, [proxyInterface.getSighash("pause()")]],
  });

  logStepEnd(__filename);
};

func.skip = async function ({ deployments, network }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip =
    (await isDeployed("RiverProxyFirewall", deployments, __filename)) &&
    (await isDeployed("OracleProxyFirewall", deployments, __filename)) &&
    (await isDeployed("OperatorsRegistryProxyFirewall", deployments, __filename)) &&
    (await isDeployed("AllowlistProxyFirewall", deployments, __filename));
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
