import hre from "hardhat";
import {
  REDEEM_MANAGER,
  UPGRADE_BLOCK,
  buildCorrectedQueue,
  claimNetting,
  historyProvider,
  redeemManagerAt,
  reconstructPreUpgrade,
  verifyQueue,
  withdrawalStackEnd,
  eth,
} from "./lib";

// BS-4878 damage, exposure and post-repair solvency assessment. Read only.
//
//   npx hardhat run hardhat_scripts/bs4878/assess.ts --network hoodi
//
// Section 4 is the gate on the repair plan: it must report SOLVENT before claims are re-enabled.
// Re-run this against the frozen state immediately before repairing - the numbers move with every
// claim, and the headroom is thin.

async function main() {
  const history = historyProvider(hre.ethers);
  const rm = await redeemManagerAt(hre, hre.ethers.provider);
  const count = (await rm.getRedeemRequestCount()).toNumber();
  console.log(`hoodi RedeemManager ${REDEEM_MANAGER}   queue length ${count}\n`);

  const legacy = await reconstructPreUpgrade(hre, history);

  console.log("=".repeat(78));
  console.log("1. per-field damage across the pre-upgrade requests");
  console.log("=".repeat(78));
  const counters: Record<string, number> = {
    amount: 0,
    maxRedeemableEth: 0,
    recipient: 0,
    height: 0,
    initiator: 0,
  };
  let payloadDamaged = 0;
  let intact = 0;
  for (const [id, want] of legacy) {
    const got = await rm.getRedeemRequestDetails(id);
    const bad: string[] = [];
    if (!got.amount.eq(want.amount)) bad.push("amount");
    if (!got.maxRedeemableEth.eq(want.maxRedeemableEth)) bad.push("maxRedeemableEth");
    if (got.recipient.toLowerCase() !== want.recipient) bad.push("recipient");
    if (!got.height.eq(want.height)) bad.push("height");
    if (got.initiator.toLowerCase() !== want.initiator) bad.push("initiator");
    bad.forEach((f) => (counters[f] += 1));
    if (bad.length === 0) intact += 1;
    else if (bad.some((f) => f !== "initiator")) payloadDamaged += 1;
  }
  console.log(`  fully intact: ${intact}   payload-damaged: ${payloadDamaged}`);
  for (const [f, n] of Object.entries(counters)) console.log(`    ${f.padEnd(18)}${n}`);
  const openLegacy = [...legacy.values()].filter((r) => r.open);
  console.log(`  open at upgrade: ${openLegacy.length}`);

  console.log("\n" + "=".repeat(78));
  console.log("2. claims since the BYOV upgrade");
  console.log("=".repeat(78));
  const head = await history.getBlockNumber();
  const netting = await claimNetting(hre, history, legacy.size, head);
  if (netting.size === 0) {
    console.log("  none against the corrupted region");
  }
  for (const [source, acc] of netting) {
    console.log(
      `  claim(s) on corrupted id ${JSON.stringify(acc.from)} consumed request ${source}'s entitlement: ` +
        `${eth(acc.lsETH)} LsETH / ${eth(acc.eth)} ETH`
    );
    console.log(`    -> the repair nets this against ${source}, otherwise it could be claimed twice`);
  }

  console.log("\n" + "=".repeat(78));
  console.log("3. live exposure");
  console.log("=".repeat(78));
  const coverage = await withdrawalStackEnd(rm);
  const balance = await hre.ethers.provider.getBalance(REDEEM_MANAGER);
  const absurd: number[] = [];
  let claimable = 0;
  for (const id of legacy.keys()) {
    const d = await rm.getRedeemRequestDetails(id);
    if (d.amount.gt(0) && d.height.lt(coverage)) {
      claimable += 1;
      if (d.amount.gt(hre.ethers.utils.parseEther("1000000"))) absurd.push(id);
    }
  }
  console.log(`  withdrawal coverage 0..${eth(coverage)} LsETH   balance ${eth(balance)} ETH`);
  console.log(`  corrupted ids claimable now: ${claimable}   of which absurd amounts: ${absurd.length}`);
  console.log(`    ${JSON.stringify(absurd)}`);
  console.log("  -> freeze claims before repairing; one such claim can exhaust the solvency headroom");

  console.log("\n" + "=".repeat(78));
  console.log("4. post-repair solvency");
  console.log("=".repeat(78));
  const rows = await buildCorrectedQueue(hre, history, hre.ethers.provider);
  const demand = await rm.getRedeemDemand();
  const { queueEnd } = verifyQueue(rows, coverage, demand);
  console.log(`  repaired queue end : ${eth(queueEnd)} LsETH`);
  console.log(`  coverage           : ${eth(coverage)} LsETH`);
  console.log(`  implied demand     : ${eth(queueEnd.sub(coverage))}`);
  console.log(`  redeemDemand()     : ${eth(demand)}   match: true`);

  let owed = hre.ethers.constants.Zero;
  let stillOpen = 0;
  for (const r of rows) {
    if (r.amount.isZero()) continue;
    stillOpen += 1;
    const endPos = r.height.add(r.amount);
    const portion = (endPos.lt(coverage) ? endPos : coverage).sub(r.height);
    if (portion.gt(0)) owed = owed.add(r.maxRedeemableEth.mul(portion).div(r.amount));
  }
  const solvent = balance.gte(owed);
  console.log(`\n  ETH claimable immediately after repair : ${eth(owed)}`);
  console.log(`  contract balance                       : ${eth(balance)}`);
  console.log(`  -> ${solvent ? "SOLVENT" : "SHORT"} by ${eth(solvent ? balance.sub(owed) : owed.sub(balance))} ETH`);
  console.log(`  open requests after repair: ${stillOpen}`);
  if (!solvent) process.exitCode = 1;
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
