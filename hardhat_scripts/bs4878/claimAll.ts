import hre from "hardhat";
import { ethers as EthersType } from "ethers";
import {
  REDEEM_MANAGER,
  claimNetting,
  historyProvider,
  redeemManagerAt,
  reconstructPreUpgrade,
  retry,
  withdrawalStackEnd,
  eth,
} from "./redeemQueueRepair";

// BS-4878: claim every remaining redeem request on a repaired fork and check each payout against the
// pre BYOV-upgrade values.
//
//   npx hardhat run hardhat_scripts/bs4878/claimAll.ts --network tenderly
//
// The reference is reconstructPreUpgrade - the queue as it stood before the upgrade at hoodi block
// 3027299 (2026-06-16 10:55 UTC) - with the one claim booked against the corrupted region netted
// against the request it actually consumed.
//
// Requests are claimed one per transaction so every payout can be attributed to a single recipient
// with no ambiguity. Requests whose range sits beyond the withdrawal stack are expected to be
// unclaimable: that is normal protocol behaviour awaiting the next oracle reports, not damage.
//
// Only run this against a Virtual TestNet.

const CALLER = "0x00000000000000000000000000000000beef4878";

async function main() {
  const url = (hre.network.config as any).url as string;
  if (!url) throw new Error("run with --network tenderly and TENDERLY_RPC_URL set");
  const provider = new hre.ethers.providers.JsonRpcProvider(url);
  const net = await provider.getNetwork();
  if (net.chainId === 560048) throw new Error("refusing to run against real hoodi");
  console.log(`fork chainId=${net.chainId} block=${await provider.getBlockNumber()}\n`);

  await provider.send("tenderly_setBalance", [CALLER, hre.ethers.utils.hexValue(hre.ethers.utils.parseEther("1000"))]);
  const caller = provider.getSigner(CALLER);

  const history = historyProvider(hre.ethers);
  const rm = await redeemManagerAt(hre, provider);
  const rmCaller = rm.connect(caller);

  // Pre BYOV-upgrade truth, netted for the claim booked against the corrupted region.
  const pre = await reconstructPreUpgrade(hre, history);
  const netting = await claimNetting(hre, history, pre.size, Math.min(await provider.getBlockNumber(), await history.getBlockNumber()));

  const coverage = await withdrawalStackEnd(rm);
  const count = (await rm.getRedeemRequestCount()).toNumber();
  console.log(`queue length ${count}   withdrawal coverage ${eth(coverage)} LsETH`);
  console.log(`RedeemManager balance ${eth(await provider.getBalance(REDEEM_MANAGER))} ETH\n`);

  const open: number[] = [];
  const before = new Map<number, any>();
  for (let i = 0; i < count; ++i) {
    const d = await retry<any>(() => rm.getRedeemRequestDetails(i));
    before.set(i, d);
    if (d.amount.gt(0)) open.push(i);
  }
  console.log(`open requests: ${open.length}\n`);

  const rows: string[] = [];
  let claimedCount = 0;
  let pendingCount = 0;
  let recipientMismatch = 0;
  let amountMismatch = 0;
  let totalPaid = hre.ethers.constants.Zero;

  for (const id of open) {
    const cur = before.get(id)!;
    const resolved = await retry<any>(() => rm.resolveRedeemRequests([id]));
    const eventId: EthersType.BigNumber = resolved[0];

    if (eventId.lt(0)) {
      pendingCount += 1;
      rows.push(
        `  ${String(id).padStart(4)}  PENDING   ${eth(cur.amount).padStart(14)} LsETH  ` +
          `beyond withdrawal coverage (resolve=${eventId.toString()})`
      );
      continue;
    }

    // Expected payout: the whole cap for a request fully inside coverage, pro rata otherwise.
    const endPos = cur.height.add(cur.amount);
    const portion = (endPos.lt(coverage) ? endPos : coverage).sub(cur.height);
    const expectedEth = cur.maxRedeemableEth.mul(portion).div(cur.amount);

    const balBefore = await retry(() => provider.getBalance(cur.recipient));
    await (
      await rmCaller["claimRedeemRequests(uint32[],uint32[])"]([id], [eventId], { gasLimit: 8_000_000 })
    ).wait();
    const paid = (await retry(() => provider.getBalance(cur.recipient))).sub(balBefore);
    totalPaid = totalPaid.add(paid);
    claimedCount += 1;

    // Check against the pre-upgrade record rather than against what the chain says today.
    const ref = pre.get(id);
    let refRecipient = ref ? ref.recipient : "(created after the upgrade)";
    let refAmount = ref ? ref.amount : null;
    if (ref && netting.has(id)) refAmount = refAmount!.sub(netting.get(id)!.lsETH);

    const recipientOk = !ref || ref.recipient.toLowerCase() === cur.recipient.toLowerCase();
    const amountOk = !refAmount || refAmount.eq(cur.amount);
    if (!recipientOk) recipientMismatch += 1;
    if (!amountOk) amountMismatch += 1;

    const after = await retry<any>(() => rm.getRedeemRequestDetails(id));
    const settled = after.amount.isZero() ? "full" : `partial, ${eth(after.amount)} left`;
    const payoutOk = paid.eq(expectedEth);

    rows.push(
      `  ${String(id).padStart(4)}  ${payoutOk ? "OK      " : "PAYOUT !"}  ${eth(paid).padStart(14)} ETH  ` +
        `${settled.padEnd(24)} ${cur.recipient}  ` +
        `${recipientOk ? "recipient ok" : "RECIPIENT MISMATCH vs " + refRecipient}  ` +
        `${amountOk ? "amount ok" : "AMOUNT MISMATCH vs " + refAmount!.toString()}`
    );
  }

  console.log(rows.join("\n"));

  const demandAfter = await rm.getRedeemDemand();
  const balAfter = await provider.getBalance(REDEEM_MANAGER);
  let stillOpen = hre.ethers.constants.Zero;
  let stillOpenCount = 0;
  for (let i = 0; i < count; ++i) {
    const d = await retry<any>(() => rm.getRedeemRequestDetails(i));
    if (d.amount.gt(0)) {
      stillOpen = stillOpen.add(d.amount);
      stillOpenCount += 1;
    }
  }

  console.log("\n" + "=".repeat(96));
  console.log(`claimed            : ${claimedCount}`);
  console.log(`pending (uncovered): ${pendingCount}`);
  console.log(`total ETH paid out : ${eth(totalPaid)}`);
  console.log(`recipient mismatches vs pre-upgrade : ${recipientMismatch}`);
  console.log(`amount    mismatches vs pre-upgrade : ${amountMismatch}`);
  console.log(`\nstill open after claiming : ${stillOpenCount} requests, ${eth(stillOpen)} LsETH`);
  console.log(`redeemDemand()            : ${eth(demandAfter)} LsETH`);
  console.log(`RedeemManager balance     : ${eth(balAfter)} ETH`);
  console.log("=".repeat(96));

  if (recipientMismatch || amountMismatch) {
    throw new Error("pre-upgrade values were not preserved");
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
