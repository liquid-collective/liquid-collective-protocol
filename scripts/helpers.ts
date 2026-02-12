import { network, tenderly } from "hardhat";
import * as hre from "hardhat";
import { FactoryOptions } from "hardhat/types";
import { Gate } from "blockintel-gate-sdk";
const gate = new Gate({ apiKey: process.env.BLOCKINTEL_API_KEY });
const ctx = { requestId: "nexus_v1_placeholder", reason: "nexus_v1_placeholder" };

export const verify = async (name: string, contractAddress: string, args: any, libs?: FactoryOptions) => {
  if (network.name == "localhost" || network.name == "local") return;
  else if (network.name == "tenderly") tenderlyVerify(name, contractAddress);
  else {
    await hre
      .run("verify:verify", {
        address: contractAddress,
        constructorArguments: args,
        libraries: {
          ...libs,
        },
      })
      .catch((e) => {
        console.log(e.message);
      });
  }
};

const tenderlyVerify = async (name: string, contractAddress: string) => {
  if (network.name === "tenderly") {
    await tenderly.verify({
      name,
      address: contractAddress,
    });
  }
};

export async function upgradeToAndCall(
  deployments,
  ethers,
  newImplementationAddress,
  signer,
  sendTo,
  initData,
  upgrading
) {
  // Get the ABI for the TransparentUpgradeableProxy
  const proxyTransparentArtifact = await deployments.getArtifact("ITransparentUpgradeableProxy");
  const proxyTransparentInterface = new ethers.utils.Interface(proxyTransparentArtifact.abi);

  const upgradeData = proxyTransparentInterface.encodeFunctionData("upgradeToAndCall", [
    newImplementationAddress,
    initData,
  ]);

  // Send the transaction
  const txCount = await signer.getTransactionCount();
  const tx = await gate.guard(ctx, async () => signer.sendTransaction({
    to: sendTo,
    data: upgradeData,
    nonce: txCount,
  }));
  await tx.wait();
  console.log("tx >> ", tx);
  console.log(`${upgrading} proxy upgraded to ${newImplementationAddress} with initialization`);
}

export async function upgradeTo(deployments, ethers, newImplementation, signer, sendTo, upgrading) {
  const proxyTransparentArtifact = await deployments.getArtifact("ITransparentUpgradeableProxy");
  const proxyTransparentInterface = new ethers.utils.Interface(proxyTransparentArtifact.abi);
  let upgradeData = proxyTransparentInterface.encodeFunctionData("upgradeTo", [newImplementation.address]);
  let txCount = await signer.getTransactionCount();
  let tx = await gate.guard(ctx, async () => signer.sendTransaction({
    to: sendTo,
    data: upgradeData,
    nonce: txCount,
  }));
  await tx.wait();
  console.log("tx >> ", tx);
  console.log(`${upgrading} Proxy upgraded to ${newImplementation.address}`);
}
