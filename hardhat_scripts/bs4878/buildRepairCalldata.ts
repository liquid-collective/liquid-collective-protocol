import * as fs from "fs";
import hre from "hardhat";
import {
  buildCorrectedQueue,
  encodeRepairCalldata,
  historyProvider,
  redeemManagerAt,
  verifyQueue,
  withdrawalStackEnd,
  eth,
} from "./redeemQueueRepair";

// BS-4878: build and validate the calldata for RedeemManagerV1Recovery.repairRedeemQueue. Read only.
//
//   npx hardhat run hardhat_scripts/bs4878/buildRepairCalldata.ts --network hoodi
//
// Writes hardhat_scripts/bs4878/repair-calldata.txt. The artifact is gitignored on purpose: it must
// be regenerated against the frozen state, because every claim moves the numbers.

const OUT = "hardhat_scripts/bs4878/repair-calldata.txt";

async function main() {
  const history = historyProvider(hre.ethers);
  const rm = await redeemManagerAt(hre, hre.ethers.provider);

  const rows = await buildCorrectedQueue(hre, history, hre.ethers.provider);
  const coverage = await withdrawalStackEnd(rm);
  const demand = await rm.getRedeemDemand();

  const { queueEnd, impliedDemand } = verifyQueue(rows, coverage, demand);
  console.log(`  queue end    : ${queueEnd.toString()}`);
  console.log(`  coverage     : ${coverage.toString()}`);
  console.log(`  implied      : ${impliedDemand.toString()}`);
  console.log(`  redeemDemand : ${demand.toString()}`);
  console.log("  -> demand invariant holds, repairRedeemQueue will pass its checks");

  const calldata = encodeRepairCalldata(hre, rows);
  fs.writeFileSync(OUT, calldata + "\n");

  const open = rows.filter((r) => r.amount.gt(0));
  console.log(`\n  requests encoded : ${rows.length}`);
  console.log(`  open after repair: ${open.length}`);
  console.log(`  LsETH still owed : ${eth(open.reduce((a, r) => a.add(r.amount), hre.ethers.constants.Zero))}`);
  console.log(`  calldata bytes   : ${(calldata.length - 2) / 2}`);
  console.log(`  wrote ${OUT}`);
  console.log("\n  Send from the RedeemManagerProxyFirewall as:");
  console.log(`    upgradeToAndCall(<RedeemManagerV1Recovery>, <${OUT}>)`);
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
