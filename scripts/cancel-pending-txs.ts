import * as hre from "hardhat";

async function main() {
  const { ethers } = hre;
  const [signer] = await ethers.getSigners();
  const address = await signer.getAddress();
  const provider = ethers.provider;

  const confirmedNonce = await provider.getTransactionCount(address, "latest");
  const pendingNonce = await provider.getTransactionCount(address, "pending");

  console.log(`Address: ${address}`);
  console.log(`Confirmed nonce: ${confirmedNonce} / Pending nonce: ${pendingNonce}`);

  if (pendingNonce <= confirmedNonce) {
    console.log("No pending transactions.");
    return;
  }

  const feeData = await provider.getFeeData();
  const gasPrice = (feeData.gasPrice! * BigInt(15)) / BigInt(10); // 50% above current

  console.log(
    `Cancelling ${pendingNonce - confirmedNonce} pending tx(s), gasPrice: ${(Number(gasPrice) / 1e9).toFixed(2)} gwei`
  );

  for (let nonce = confirmedNonce; nonce < pendingNonce; nonce++) {
    const tx = await signer.sendTransaction({
      to: address,
      value: 0,
      nonce,
      gasPrice,
      gasLimit: 21000,
    });
    console.log(`Cancel tx sent for nonce ${nonce}: ${tx.hash}`);
    await tx.wait();
    console.log(`Confirmed.`);
  }
  console.log("All pending txs cancelled.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
