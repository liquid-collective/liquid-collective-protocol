import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, ethers }: HardhatRuntimeEnvironment) {
  const { proxyAdministrator, governor } = await getNamedAccounts();

  const allowlistNewImplementationDeployment = await deployments.get("AllowlistV1_Implementation_1_2_0");
  const coverageFundNewImplementationDeployment = await deployments.get("CoverageFundV1_Implementation_1_2_0");
  const elFeeRecipientNewImplementationDeployment = await deployments.get("ELFeeRecipientV1_Implementation_1_2_0");
  const operatorsRegistryNewImplementationDeployment = await deployments.get(
    "OperatorsRegistryV1_Implementation_1_2_0"
  );
  const oracleNewImplementationDeployment = await deployments.get("OracleV1_Implementation_1_2_0");
  const redeemManagerNewImplementationDeployment = await deployments.get("RedeemManagerV1_Implementation_1_2_0");
  const riverNewImplementationDeployment = await deployments.get("RiverV1_Implementation_1_2_0");
  const withdrawNewImplementationDeployment = await deployments.get("WithdrawV1_Implementation_1_2_0");

  const riverProxyFirewallDeployment = await deployments.get("RiverProxyFirewall");
  const operatorsRegistryFirewallDeployment = await deployments.get("OperatorsRegistryProxyFirewall");
  const oracleProxyFirewallDeployment = await deployments.get("OracleProxyFirewall");
  const redeemManagerProxyFirewallDeployment = await deployments.get("RedeemManagerProxyFirewall");
  const allowlistProxyFirewallDeployment = await deployments.get("AllowlistProxyFirewall");
  const withdrawProxyDeployment = await deployments.get("Withdraw");
  const coverageFundProxyDeployment = await deployments.get("CoverageFund");
  const eLFeeRecipientProxyDeployment = await deployments.get("ELFeeRecipient");
  const proxyAdministratorSigner = await ethers.getSigner(proxyAdministrator);

  await upgradeTo(
    deployments,
    ethers,
    allowlistNewImplementationDeployment,
    proxyAdministratorSigner,
    allowlistProxyFirewallDeployment.address,
    "Allowlist"
  );

  await upgradeTo(
    deployments,
    ethers,
    coverageFundNewImplementationDeployment,
    proxyAdministratorSigner,
    coverageFundProxyDeployment.address,
    "CoverageFund"
  );

  await upgradeTo(
    deployments,
    ethers,
    elFeeRecipientNewImplementationDeployment,
    proxyAdministratorSigner,
    eLFeeRecipientProxyDeployment.address,
    "ELFeeRecipient"
  );

  await upgradeTo(
    deployments,
    ethers,
    oracleNewImplementationDeployment,
    proxyAdministratorSigner,
    oracleProxyFirewallDeployment.address,
    "Oracle"
  );

  await upgradeTo(
    deployments,
    ethers,
    operatorsRegistryNewImplementationDeployment,
    proxyAdministratorSigner,
    operatorsRegistryFirewallDeployment.address,
    "OperatorsRegistry"
  );

  await upgradeTo(
    deployments,
    ethers,
    redeemManagerNewImplementationDeployment,
    proxyAdministratorSigner,
    redeemManagerProxyFirewallDeployment.address,
    "RedeemManager"
  );

  await upgradeTo(
    deployments,
    ethers,
    riverNewImplementationDeployment,
    proxyAdministratorSigner,
    riverProxyFirewallDeployment.address,
    "River"
  );
  await upgradeTo(
    deployments,
    ethers,
    withdrawNewImplementationDeployment,
    proxyAdministratorSigner,
    withdrawProxyDeployment.address,
    "Withdraw"
  );

  // TODO: Have to add a keeper transaction setKeeper
};

async function upgradeTo(deployments, ethers, newImplementation, signer, sendTo, upgrading) {
  const proxyTransparentArtifact = await deployments.getArtifact("ITransparentUpgradeableProxy");
  const proxyTransparentInterface = new ethers.utils.Interface(proxyTransparentArtifact.abi);
  let upgradeData = proxyTransparentInterface.encodeFunctionData("upgradeTo", [newImplementation.address]);
  let txCount = await signer.getTransactionCount();
  let tx = await signer.sendTransaction({
    to: sendTo,
    data: upgradeData,
    nonce: txCount,
  });
  await tx.wait();
  console.log("tx >> ", tx);
  console.log(`${upgrading} Proxy upgraded to ${newImplementation.address}`);
}

export default func;
