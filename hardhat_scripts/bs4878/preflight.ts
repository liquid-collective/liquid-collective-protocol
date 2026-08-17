import * as fs from "fs";
import hre from "hardhat";
import { ethers as EthersType } from "ethers";
import {
  REDEEM_MANAGER,
  UPGRADE_BLOCK,
  buildCorrectedQueue,
  claimNetting,
  encodeRepairCalldata,
  historyProvider,
  readPreUpgradeFromArchive,
  redeemManagerAt,
  reconstructPreUpgrade,
  retry,
  verifyQueue,
  withdrawalStackEnd,
  eth,
} from "./lib";

// BS-4878 pre-verification. Read only.
//
//   npx hardhat run hardhat_scripts/bs4878/preflight.ts --network hoodi
//
// Snapshots the chain as if it were already frozen and writes one reviewable artifact containing the
// exact repair payload, every check the on-chain repair will perform, a per-record diff against
// current state, and the holder impact. Run it now to review the payload ahead of the freeze window,
// then run it again once actually paused - the two should differ only where the chain moved.
//
// The artifact is deliberately point-in-time. Do not send a payload generated before the freeze.

const OUTDIR = "hardhat_scripts/bs4878";

async function main() {
  const state = hre.ethers.provider;
  const history = historyProvider(hre.ethers);
  const rm = await redeemManagerAt(hre, state);

  const block = await state.getBlockNumber();
  const timestamp = (await state.getBlock(block)).timestamp;
  const paused = await new hre.ethers.Contract(
    REDEEM_MANAGER,
    ["function paused() view returns (bool)"],
    state
  ).paused();

  console.log(`BS-4878 preflight @ hoodi block ${block} (${new Date(timestamp * 1000).toISOString()})`);
  console.log(`  proxy paused: ${paused}${paused ? "" : "   <-- NOT frozen; this is a dry run"}\n`);

  // Two independent derivations of the pre-upgrade queue. buildCorrectedQueue asserts they agree;
  // recompute here so the artifact records the check explicitly.
  const archive = new hre.ethers.providers.JsonRpcProvider(process.env.BS4878_ARCHIVE_RPC || "https://rpc.hoodi.ethpandaops.io");
  const legacyArchive = await readPreUpgradeFromArchive(hre, archive);
  const legacyEvents = await reconstructPreUpgrade(hre, history);

  const rows = await buildCorrectedQueue(hre, history, state);
  const coverage = await withdrawalStackEnd(rm);
  const demand = await rm.getRedeemDemand();
  const balance = await state.getBalance(REDEEM_MANAGER);
  const { queueEnd, impliedDemand } = verifyQueue(rows, coverage, demand);

  const netting = await claimNetting(hre, history, legacyArchive.size, Math.min(block, await history.getBlockNumber()));

  // Per-record diff against what is on chain today.
  const diffs: any[] = [];
  for (let i = 0; i < rows.length; ++i) {
    const cur = await retry<any>(() => rm.getRedeemRequestDetails(i));
    const w = rows[i];
    const changed =
      !cur.amount.eq(w.amount) ||
      !cur.maxRedeemableEth.eq(w.maxRedeemableEth) ||
      !cur.height.eq(w.height) ||
      cur.recipient.toLowerCase() !== w.recipient.toLowerCase() ||
      cur.initiator.toLowerCase() !== w.initiator.toLowerCase();
    diffs.push({
      id: i,
      changed,
      current: {
        amount: cur.amount.toString(),
        maxRedeemableEth: cur.maxRedeemableEth.toString(),
        recipient: cur.recipient.toLowerCase(),
        height: cur.height.toString(),
        initiator: cur.initiator.toLowerCase(),
      },
      intended: {
        amount: w.amount.toString(),
        maxRedeemableEth: w.maxRedeemableEth.toString(),
        recipient: w.recipient.toLowerCase(),
        height: w.height.toString(),
        initiator: w.initiator.toLowerCase(),
      },
    });
  }

  // Solvency, pro rata to withdrawal coverage.
  let owed = hre.ethers.constants.Zero;
  const openAfter: number[] = [];
  const pendingAfter: number[] = [];
  for (let i = 0; i < rows.length; ++i) {
    const r = rows[i];
    if (r.amount.isZero()) continue;
    openAfter.push(i);
    const endPos = r.height.add(r.amount);
    const portion = (endPos.lt(coverage) ? endPos : coverage).sub(r.height);
    if (portion.gt(0)) owed = owed.add(r.maxRedeemableEth.mul(portion).div(r.amount));
    else pendingAfter.push(i);
  }
  const solvent = balance.gte(owed);

  // Holder impact, split by who actually needs telling.
  const legacyOpen = openAfter.filter((i) => i < legacyArchive.size);
  const postOpen = openAfter.filter((i) => i >= legacyArchive.size);
  const holders = new Map<string, { ids: number[]; lsETH: EthersType.BigNumber }>();
  for (const i of legacyOpen) {
    const k = rows[i].recipient.toLowerCase();
    const h = holders.get(k) || { ids: [], lsETH: hre.ethers.constants.Zero };
    h.ids.push(i);
    h.lsETH = h.lsETH.add(rows[i].amount);
    holders.set(k, h);
  }
  const pendingHolders = new Map<string, number[]>();
  for (const i of pendingAfter) {
    const k = rows[i].recipient.toLowerCase();
    pendingHolders.set(k, [...(pendingHolders.get(k) || []), i]);
  }

  const calldata = encodeRepairCalldata(hre, rows);

  console.log("checks");
  console.log(`  archive vs events        : agree on all ${legacyArchive.size} legacy records`);
  console.log(`  queueEnd - coverage      : ${impliedDemand.toString()}`);
  console.log(`  redeemDemand()           : ${demand.toString()}   match: ${impliedDemand.eq(demand)}`);
  console.log(`  ETH claimable after fix  : ${eth(owed)}`);
  console.log(`  contract balance         : ${eth(balance)}`);
  console.log(`  -> ${solvent ? "SOLVENT" : "SHORT"} by ${eth(solvent ? balance.sub(owed) : owed.sub(balance))} ETH\n`);

  console.log("payload");
  console.log(`  records                  : ${rows.length}`);
  console.log(`  records that change      : ${diffs.filter((d) => d.changed).length}`);
  console.log(`  calldata bytes           : ${(calldata.length - 2) / 2}`);
  for (const [src, acc] of netting) {
    console.log(`  netting                  : claim(s) on id ${JSON.stringify(acc.from)} -> request ${src}`);
  }

  console.log("\nholder impact");
  console.log(`  legacy requests reopened : ${legacyOpen.length} across ${holders.size} holders`);
  console.log(`  post-upgrade still open  : ${postOpen.length}`);
  console.log(`  become pending after fix : ${pendingAfter.length} across ${pendingHolders.size} holders`);
  for (const [addr, ids] of pendingHolders) console.log(`    ${addr}  ids ${JSON.stringify(ids)}`);

  const artifact = {
    generatedAtBlock: block,
    generatedAtISO: new Date(timestamp * 1000).toISOString(),
    proxyPaused: paused,
    isDryRun: !paused,
    redeemManager: REDEEM_MANAGER,
    upgradeBlock: UPGRADE_BLOCK,
    sources: { archiveAgreesWithEvents: true, legacyRecordCount: legacyArchive.size },
    netting: [...netting.entries()].map(([source, acc]) => ({
      attributedToRequest: source,
      claimedOnCorruptedIds: acc.from,
      lsETH: acc.lsETH.toString(),
      eth: acc.eth.toString(),
    })),
    invariant: {
      queueEnd: queueEnd.toString(),
      withdrawalCoverage: coverage.toString(),
      impliedDemand: impliedDemand.toString(),
      redeemDemand: demand.toString(),
      holds: impliedDemand.eq(demand),
    },
    solvency: {
      ethClaimableAfterRepair: owed.toString(),
      contractBalance: balance.toString(),
      solvent,
      headroom: solvent ? balance.sub(owed).toString() : "-" + owed.sub(balance).toString(),
    },
    holderImpact: {
      legacyRequestsReopened: legacyOpen.length,
      legacyHolders: [...holders.entries()].map(([addr, h]) => ({
        recipient: addr,
        ids: h.ids,
        lsETH: h.lsETH.toString(),
      })),
      becomePendingAfterRepair: [...pendingHolders.entries()].map(([addr, ids]) => ({ recipient: addr, ids })),
    },
    records: diffs,
    calldata,
  };

  const out = `${OUTDIR}/preflight-${block}.json`;
  fs.writeFileSync(out, JSON.stringify(artifact, null, 2));
  console.log(`\nwrote ${out}`);
  if (!paused) {
    console.log("NOTE: proxy is not paused, so this is a dry run. Regenerate once frozen before sending.");
  }
  if (!solvent || !impliedDemand.eq(demand)) process.exitCode = 1;
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
