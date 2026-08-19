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
} from "../redeem_queue_repair";

// BS-4878: claim every remaining redeem request on a repaired fork and check each payout against the
// pre BYOV-upgrade values.
//
//   npx hardhat run hardhat_scripts/staging_redeem_queue_migration/tenderly/01_claim_all.ts --network tenderly
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

  // Compare against the pre-upgrade truth before claiming anything, not once per claim inside the loop
  // below. `netting` is built from `history`, which is the real network, so it cannot see claims made on
  // the fork. A fork that has already been claimed against - a rerun of this script, or the smoke test
  // at the end of hoodi/02_execute_repair.ts - therefore holds amounts legitimately below the netted
  // pre-upgrade ones, and comparing per claim would report that correct queue as a failed repair.
  //
  // Checking up front also separates the two cases. An amount below the reference means the fork has
  // moved on and there is nothing left to validate here; anything else different means the repair
  // itself is wrong. Those need different answers, so they get different errors.
  const drifted: string[] = [];
  const wrong: string[] = [];
  let compared = 0;
  for (const id of open) {
    const ref = pre.get(id);
    // Requests created after the upgrade have no pre-upgrade record to compare against.
    if (!ref) continue;
    const cur = before.get(id)!;
    const refAmount = netting.has(id) ? ref.amount.sub(netting.get(id)!.lsETH) : ref.amount;
    compared += 1;

    if (ref.recipient.toLowerCase() !== cur.recipient.toLowerCase()) {
      wrong.push(`${id}: recipient ${cur.recipient}, expected ${ref.recipient}`);
    }
    if (cur.amount.lt(refAmount)) {
      drifted.push(`${id}: ${eth(cur.amount)} < ${eth(refAmount)} LsETH`);
    } else if (!cur.amount.eq(refAmount)) {
      wrong.push(`${id}: amount ${cur.amount.toString()}, expected ${refAmount.toString()}`);
    }
  }

  if (wrong.length) {
    throw new Error(`pre-upgrade values were not preserved: ${wrong.slice(0, 8).join("; ")}`);
  }
  if (drifted.length) {
    throw new Error(
      "this fork has already been claimed against, so the pre-upgrade comparison cannot run: " +
        `${drifted.slice(0, 8).join("; ")} - reset the Virtual TestNet and rerun`
    );
  }
  console.log(`pre-upgrade comparison: ${compared} legacy request(s) match, recipients and amounts\n`);

  const rows: string[] = [];
  let claimedCount = 0;
  let pendingCount = 0;
  let payoutMismatch = 0;
  let totalPaid = hre.ethers.constants.Zero;

  for (const id of open) {
    const cur = before.get(id)!;
    const resolved = await retry<any>(() => rm.resolveRedeemRequests([id]));
    const raw = resolved[0];
    const eventIdSigned =
      typeof raw === "number" ? raw : EthersType.BigNumber.from(raw).fromTwos(64).toNumber();

    if (eventIdSigned < 0) {
      pendingCount += 1;
      rows.push(
        `  ${String(id).padStart(4)}  PENDING   ${eth(cur.amount).padStart(14)} LsETH  ` +
          `beyond withdrawal coverage (resolve=${eventIdSigned})`
      );
      continue;
    }
    const eventId = eventIdSigned;

    // Expected payout: the whole cap for a request fully inside coverage, pro rata otherwise.
    const endPos = cur.height.add(cur.amount);
    const portion = (endPos.lt(coverage) ? endPos : coverage).sub(cur.height);
    const expectedEth = cur.maxRedeemableEth.mul(portion).div(cur.amount);

    const balBefore = await retry(() => provider.getBalance(cur.recipient));
    await (
      await rmCaller["claimRedeemRequests(uint32[],uint32[])" ]([id], [eventId], { gasLimit: 8_000_000 })
    ).wait();
    const paid = (await retry(() => provider.getBalance(cur.recipient))).sub(balBefore);
    totalPaid = totalPaid.add(paid);
    claimedCount += 1;

    const after = await retry<any>(() => rm.getRedeemRequestDetails(id));
    const settled = after.amount.isZero() ? "full" : `partial, ${eth(after.amount)} left`;
    const payoutOk = paid.eq(expectedEth);
    if (!payoutOk) payoutMismatch += 1;

    rows.push(
      `  ${String(id).padStart(4)}  ${payoutOk ? "OK      " : "PAYOUT !"}  ${eth(paid).padStart(14)} ETH  ` +
        `${settled.padEnd(24)} ${cur.recipient}` +
        `${payoutOk ? "" : `  expected ${eth(expectedEth)} ETH`}`
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
  // Not fatal: expectedEth divides once per request while the contract prices each withdrawal event
  // separately, so a request straddling the coverage boundary can differ by a few wei. Reported rather
  // than thrown so a rounding difference is not mistaken for a broken payout.
  console.log(`payout differences from expected    : ${payoutMismatch}`);
  console.log(`\nstill open after claiming : ${stillOpenCount} requests, ${eth(stillOpen)} LsETH`);
  console.log(`redeemDemand()            : ${eth(demandAfter)} LsETH`);
  console.log(`RedeemManager balance     : ${eth(balAfter)} ETH`);
  console.log("=".repeat(96));
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
