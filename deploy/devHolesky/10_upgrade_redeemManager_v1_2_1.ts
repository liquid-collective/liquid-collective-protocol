import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, ethers, network }: HardhatRuntimeEnvironment) { 
  if ("tenderly" != network.name) {
    throw new Error("Invalid network for holesky deployment");
  }
  try {
    const { proxyAdministrator, deployer } = await getNamedAccounts();

    const redeemManagerDeployment = await deployments.deploy("RedeemManagerV1_Implementation_1_2_1", {
      contract: "RedeemManagerV1",
      from: deployer,
      log: true,
    });
    
    const redeemManagerProxyFirewallDeployment = await deployments.get("RedeemManagerProxyFirewall");
    const proxyAdministratorSigner = await ethers.getSigner(proxyAdministrator);

    // initiator addresses for the initial 7 redeem requests created before initiator was introduced.
    const prevInitiators = [
      "0x4d1bed3a669186130daaf5859b242f3c788d736a",
      "0xffc58b6a27f6354eba6bb8f39fe163a1625c4b5b",
      "0xffc58b6a27f6354eba6bb8f39fe163a1625c4b5b",
      "0xffc58b6a27f6354eba6bb8f39fe163a1625c4b5b",
      "0xffc58b6a27f6354eba6bb8f39fe163a1625c4b5b",
      "0xce8dad716539e764895cf30e64466e4e82f278bc",
      "0xffc58b6a27f6354eba6bb8f39fe163a1625c4b5b",
    ] // addresses gotten onchain

    // Call the `upgradeToAndCall` function and pass the encoded initialization data.
    await upgradeToAndCall(
      deployments,
      ethers,
      redeemManagerDeployment.address,
      proxyAdministratorSigner,
      redeemManagerProxyFirewallDeployment.address,
      prevInitiators
    );

    await verify("RedeemManagerV1", redeemManagerDeployment.implementation, []);
  
    logStepEnd(__filename);
  
  } catch (error) {
    console.error("Upgrade failed:", error);
  }
};

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


func.skip = async function ({ deployments, network }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = ["mainnet", "holesky", "devHolesky"].includes(network.name) || (await isDeployed("RedeemManagerV1", deployments, __filename));
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};


export default func;
