import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, ethers }: HardhatRuntimeEnvironment) {
  // const { proxyAdministrator, governor } = await getNamedAccounts();

  // const allowlistNewImplementationDeployment = await deployments.get("AllowlistV1_Implementation_1_2_1");
  // const coverageFundNewImplementationDeployment = await deployments.get("CoverageFundV1_Implementation_1_2_1");
  // const elFeeRecipientNewImplementationDeployment = await deployments.get("ELFeeRecipientV1_Implementation_1_2_1");
  // const operatorsRegistryNewImplementationDeployment = await deployments.get(
  //   "OperatorsRegistryV1_Implementation_1_2_1"
  // );
  // const oracleNewImplementationDeployment = await deployments.get("OracleV1_Implementation_1_2_1");
  // const redeemManagerNewImplementationDeployment = await deployments.get("RedeemManagerV1_Implementation_1_2_1");
  // const riverNewImplementationDeployment = await deployments.get("RiverV1_Implementation_1_2_1");
  // const withdrawNewImplementationDeployment = await deployments.get("WithdrawV1_Implementation_1_2_1");

  // const riverProxyFirewallDeployment = await deployments.get("RiverProxyFirewall");
  // const operatorsRegistryFirewallDeployment = await deployments.get("OperatorsRegistryProxyFirewall");
  // const oracleProxyFirewallDeployment = await deployments.get("OracleProxyFirewall");
  // const redeemManagerProxyFirewallDeployment = await deployments.get("RedeemManagerProxyFirewall");
  // const allowlistProxyFirewallDeployment = await deployments.get("AllowlistProxyFirewall");
  // const withdrawProxyDeployment = await deployments.get("Withdraw");
  // const coverageFundProxyDeployment = await deployments.get("CoverageFund");
  // const eLFeeRecipientProxyDeployment = await deployments.get("ELFeeRecipient");
  // const proxyAdministratorSigner = await ethers.getSigner(proxyAdministrator);

  // await upgradeTo(
  //   deployments,
  //   ethers,
  //   allowlistNewImplementationDeployment,
  //   proxyAdministratorSigner,
  //   allowlistProxyFirewallDeployment.address,
  //   "Allowlist"
  // );

  // await upgradeTo(
  //   deployments,
  //   ethers,
  //   coverageFundNewImplementationDeployment,
  //   proxyAdministratorSigner,
  //   coverageFundProxyDeployment.address,
  //   "CoverageFund"
  // );

  // await upgradeTo(
  //   deployments,
  //   ethers,
  //   elFeeRecipientNewImplementationDeployment,
  //   proxyAdministratorSigner,
  //   eLFeeRecipientProxyDeployment.address,
  //   "ELFeeRecipient"
  // );

  // await upgradeTo(
  //   deployments,
  //   ethers,
  //   oracleNewImplementationDeployment,
  //   proxyAdministratorSigner,
  //   oracleProxyFirewallDeployment.address,
  //   "Oracle"
  // );

  // await upgradeTo(
  //   deployments,
  //   ethers,
  //   operatorsRegistryNewImplementationDeployment,
  //   proxyAdministratorSigner,
  //   operatorsRegistryFirewallDeployment.address,
  //   "OperatorsRegistry"
  // );

  // await upgradeTo(
  //   deployments,
  //   ethers,
  //   riverNewImplementationDeployment,
  //   proxyAdministratorSigner,
  //   riverProxyFirewallDeployment.address,
  //   "River"
  // );
  // await upgradeTo(
  //   deployments,
  //   ethers,
  //   withdrawNewImplementationDeployment,
  //   proxyAdministratorSigner,
  //   withdrawProxyDeployment.address,
  //   "Withdraw"
  // );

  // // initiator addresses for the initial 7 redeem requests created before initiator was introduced.
  // const prevInitiators = [
  //   "0x4d1bed3a669186130daaf5859b242f3c788d736a",
  //   "0xffc58b6a27f6354eba6bb8f39fe163a1625c4b5b",
  //   "0xffc58b6a27f6354eba6bb8f39fe163a1625c4b5b",
  //   "0xffc58b6a27f6354eba6bb8f39fe163a1625c4b5b",
  //   "0xffc58b6a27f6354eba6bb8f39fe163a1625c4b5b",
  //   "0xce8dad716539e764895cf30e64466e4e82f278bc",
  //   "0xffc58b6a27f6354eba6bb8f39fe163a1625c4b5b",
  // ] // addresses gotten onchain
  
  //   // Call the `upgradeToAndCall` function and pass the encoded initialization data.
  //   await upgradeToAndCall(
  //     deployments,
  //     ethers,
  //     redeemManagerNewImplementationDeployment.address,
  //     proxyAdministratorSigner,
  //     redeemManagerProxyFirewallDeployment.address,
  //     prevInitiators
  //   );
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

async function upgradeToAndCall(deployments, ethers, newImplementationAddress, signer, proxyAddress, initAddresses) {
  // Get the ABI for the TransparentUpgradeableProxy
  const proxyTransparentArtifact = await deployments.getArtifact("ITransparentUpgradeableProxy");
  const proxyTransparentInterface = new ethers.utils.Interface(proxyTransparentArtifact.abi);

   // Get the ABI for the new RedeemManager implementation
   const redeemManagerArtifact = await deployments.get("RedeemManagerV1_Implementation_1_2_1");
   const redeemManagerInterface = new ethers.utils.Interface(redeemManagerArtifact.abi);
 
  // Encode the complete data for the upgradeToAndCall function
   const initData = redeemManagerInterface.encodeFunctionData("initializeRedeemManagerV1_2",[initAddresses]);
  const upgradeData = proxyTransparentInterface.encodeFunctionData("upgradeToAndCall", [
    newImplementationAddress,
    initData,
  ]);

  // Send the transaction
  const txCount = await signer.getTransactionCount();
  const tx = await signer.sendTransaction({
    to: proxyAddress,
    data: upgradeData,
    nonce: txCount
  });
  await tx.wait();
  console.log("tx >> ", tx);
  console.log(`Proxy upgraded to ${newImplementationAddress} with initialization`);

}

export default func;
