import * as fs from "fs";
import hre from "hardhat";
import {
  CLEAN_IMPL_1_3_0,
  REDEEM_MANAGER,
  REDEEM_MANAGER_PROXY_ADMIN,
  redeemManagerAt,
  withdrawalStackEnd,
  eth,
} from "../redeem_queue_repair";

// BS-4878: execute the staging repair, one step at a time.
//
//   BS4878_STEP=pause    npx hardhat run .../hoodi/03_execute_repair.ts --network hoodi
//   BS4878_STEP=deploy   ...
//   BS4878_STEP=repair   ...
//   BS4878_STEP=restore  ...
//   BS4878_STEP=unpause  ...
//
// Prints the exact transaction and stops. Nothing is sent unless BS4878_EXECUTE=1 is also set, so the
// default is always a dry run. Print-only output is enough to submit from a Safe or a hardware wallet
// instead - every step is a single call to the ProxyFirewall.
//
// Deliberately one step per invocation rather than one script that runs the sequence: the queue must
// be verified between `repair` and `restore`, and a half-finished sequence is easier to reason about
// when each transaction was a separate decision.
//
// Call path, confirmed on hoodi:
//   signer 0xf733b0ec…2f80 (Firewall admin and executor)
//     -> RedeemManagerProxyFirewall 0x0C20959C…D4BE
//       -> RedeemManager proxy 0x5d51E82b…1A00b7
// pause() is executor-allowed; unpause, upgradeTo and upgradeToAndCall are admin-only.

const CALLDATA_FILE = "hardhat_scripts/staging_redeem_queue_migration/repair-calldata.txt";
const RECOVERY_ARTIFACT = "RedeemManagerV1Recovery";

const PROXY_IFACE = new hre.ethers.utils.Interface([
  "function pause()",
  "function unpause()",
  "function paused() view returns (bool)",
  "function upgradeTo(address)",
  "function upgradeToAndCall(address,bytes)",
]);

type Step = "pause" | "deploy" | "repair" | "restore" | "unpause";

async function main() {
  const step = process.env.BS4878_STEP as Step;
  const execute = process.env.BS4878_EXECUTE === "1";
  if (!["pause", "deploy", "repair", "restore", "unpause"].includes(step ?? "")) {
    throw new Error("set BS4878_STEP to one of: pause, deploy, repair, restore, unpause");
  }

  const provider = hre.ethers.provider;
  const net = await provider.getNetwork();
  const rm = await redeemManagerAt(hre, provider);
  const zero = { from: hre.ethers.constants.AddressZero };

  // The RedeemManager proxy lets address zero through even while paused, so these reads always work.
  const paused: boolean = await new hre.ethers.Contract(REDEEM_MANAGER, PROXY_IFACE, provider).paused(zero);
  const count = (await rm.callStatic.getRedeemRequestCount(zero)).toNumber();
  const demand = await rm.callStatic.getRedeemDemand(zero);
  const coverage = await withdrawalStackEnd(rm);

  console.log(`chainId ${net.chainId}  block ${await provider.getBlockNumber()}`);
  console.log(`RedeemManager ${REDEEM_MANAGER}`);
  console.log(`  paused ${paused}   requests ${count}   redeemDemand ${eth(demand)}   coverage ${eth(coverage)}`);
  console.log(`  balance ${eth(await provider.getBalance(REDEEM_MANAGER))} ETH\n`);

  let to = REDEEM_MANAGER_PROXY_ADMIN;
  let data: string;
  let note = "";

  switch (step) {
    case "pause":
      if (paused) throw new Error("already paused");
      data = PROXY_IFACE.encodeFunctionData("pause");
      note = "stops claims. River's getRedeemDemand, reportWithdraw and pullExceedingEth all revert\n" +
             "         while paused, so oracle reports will fail until unpause. Keep the window short.";
      break;

    case "deploy": {
      const art = await hre.artifacts.readArtifact(RECOVERY_ARTIFACT);
      console.log("step: deploy RedeemManagerV1Recovery");
      console.log(`  creation bytecode: ${(art.bytecode.length - 2) / 2} bytes`);
      console.log(`  deploy from any funded account; no constructor arguments`);
      if (!execute) return void console.log("\n  dry run - set BS4878_EXECUTE=1 to deploy");
      const [signer] = await hre.ethers.getSigners();
      const c = await new hre.ethers.ContractFactory(art.abi, art.bytecode, signer).deploy({ gasLimit: 10_000_000 });
      await c.deployed();
      console.log(`  deployed at ${c.address}  <- pass this as BS4878_RECOVERY for the repair step`);
      return;
    }

    case "repair": {
      if (!paused) throw new Error("refusing to repair while unpaused - run the pause step first");
      const recovery = process.env.BS4878_RECOVERY;
      if (!recovery) throw new Error("set BS4878_RECOVERY to the deployed recovery implementation");
      if (!fs.existsSync(CALLDATA_FILE)) throw new Error(`missing ${CALLDATA_FILE} - run 02_build_repair_calldata.ts`);
      const inner = fs.readFileSync(CALLDATA_FILE, "utf8").trim();
      data = PROXY_IFACE.encodeFunctionData("upgradeToAndCall", [recovery, inner]);
      note = `upgrades to ${recovery} and repairs in one transaction.\n` +
             `         payload ${(inner.length - 2) / 2} bytes, ~4.4M gas. Regenerate it against the\n` +
             `         frozen state - a payload built before the pause may already be stale.`;
      break;
    }

    case "restore":
      if (!paused) throw new Error("proxy is not paused - is the sequence in the state you think?");
      data = PROXY_IFACE.encodeFunctionData("upgradeTo", [CLEAN_IMPL_1_3_0]);
      note = `drops the recovery surface, back to the clean 1.3.0 implementation ${CLEAN_IMPL_1_3_0}.\n` +
             `         verify the queue before running this.`;
      break;

    case "unpause":
      if (!paused) throw new Error("already unpaused");
      data = PROXY_IFACE.encodeFunctionData("unpause");
      note = "re-enables claims and unblocks oracle reports. Last step.";
      break;
  }

  console.log(`step: ${step}`);
  console.log(`  to    ${to}   (RedeemManagerProxyFirewall)`);
  console.log(`  from  must be the Firewall admin${step === "pause" ? " or executor" : " (admin only for this selector)"}`);
  console.log(`  value 0`);
  console.log(`  data  ${data!.length > 200 ? data!.slice(0, 200) + `… (${(data!.length - 2) / 2} bytes)` : data}`);
  console.log(`\n  ${note}`);

  if (!execute) {
    console.log("\n  dry run - set BS4878_EXECUTE=1 to send, or submit the transaction above yourself");
    return;
  }

  const [signer] = await hre.ethers.getSigners();
  console.log(`\n  sending from ${await signer.getAddress()}`);
  const tx = await signer.sendTransaction({ to, data: data!, gasLimit: step === "repair" ? 30_000_000 : 500_000 });
  const receipt = await tx.wait();
  console.log(`  status ${receipt.status}  gas ${receipt.gasUsed.toString()}  ${tx.hash}`);
  if (receipt.status !== 1) throw new Error("transaction reverted");
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
