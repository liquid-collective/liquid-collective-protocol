import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const version = "1_2_1"

const func: DeployFunction = async function ({ deployments, getNamedAccounts, ethers }: HardhatRuntimeEnvironment) {
  const { proxyAdministrator } = await getNamedAccounts();

  const allowlistNewImplementationDeployment = await deployments.get(`AllowlistV1_Implementation_${version}`);
  const coverageFundNewImplementationDeployment = await deployments.get(`CoverageFundV1_Implementation_${version}`);
  const elFeeRecipientNewImplementationDeployment = await deployments.get(`ELFeeRecipientV1_Implementation_${version}`);
  const operatorsRegistryNewImplementationDeployment = await deployments.get(
    `OperatorsRegistryV1_Implementation_${version}`
  );
  const oracleNewImplementationDeployment = await deployments.get(`OracleV1_Implementation_${version}`);
  const redeemManagerNewImplementationDeployment = await deployments.get(`RedeemManagerV1_Implementation_${version}`);
  const riverNewImplementationDeployment = await deployments.get(`RiverV1_Implementation_${version}`);
  const withdrawNewImplementationDeployment = await deployments.get(`WithdrawV1_Implementation_${version}`);

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

  const redeemManagerInterface = new ethers.utils.Interface(redeemManagerNewImplementationDeployment.abi);
  const initData = redeemManagerInterface.encodeFunctionData("initializeRedeemManagerV1_2");
  // Call the `upgradeToAndCall` function and pass the encoded initialization data.
  await upgradeToAndCall(
    deployments,
    ethers,
    redeemManagerNewImplementationDeployment.address,
    proxyAdministratorSigner,
    redeemManagerProxyFirewallDeployment.address,
    initData,
    "RedeemManager"
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

async function upgradeToAndCall(deployments, ethers, newImplementationAddress, signer, sendTo, initData, upgrading) {
  
  // Get the ABI for the TransparentUpgradeableProxy
  const proxyTransparentArtifact = await deployments.getArtifact("ITransparentUpgradeableProxy");
  const proxyTransparentInterface = new ethers.utils.Interface(proxyTransparentArtifact.abi);

  const upgradeData = proxyTransparentInterface.encodeFunctionData("upgradeToAndCall", [
    newImplementationAddress,
    initData,
  ]);

  // Send the transaction
  const txCount = await signer.getTransactionCount();
  const tx = await signer.sendTransaction({
    to: sendTo,
    data: upgradeData,
    nonce: txCount
  });
  await tx.wait();
  console.log("tx >> ", tx);
  console.log(`${upgrading} proxy upgraded to ${newImplementationAddress} with initialization`);

}

export default func;
