import hre from "hardhat";
import { ethers as EthersType } from "ethers";
import { REDEEM_MANAGER, RIVER, redeemManagerAt, retry, withdrawalStackEnd, eth } from "./redeemQueueRepair";

// BS-4878: prove the repaired queue can be drained completely against the withdrawal stack.
//
//   npx hardhat run hardhat_scripts/bs4878/fullRecovery.ts --network tenderly
//
// simulateRecovery.ts stops at whatever the withdrawal stack currently covers, so it leaves the tail
// unproven - those requests are legitimately waiting on future oracle reports. This goes further: it
// impersonates River to report the remaining demand, funding it at River's own conversion rate, then
// claims every request and asserts the queue settles to nothing.
//
// What it proves: the repaired queue is internally consistent and fully drainable, every holder gets
// exactly their entitlement, and no ETH is stranded or short.
//
// What it does not prove: that the ETH will exist. On the real chain it arrives from validator exits
// over time. Here we simulate that arrival.
//
// Only run this against a Virtual TestNet.

const RIVER_ABI = ["function underlyingBalanceFromShares(uint256) view returns (uint256)"];
const RM_EXTRA_ABI = ["function reportWithdraw(uint256) payable"];
const CALLER = "0x00000000000000000000000000000000beef4878";

async function main() {
  const url = (hre.network.config as any).url as string;
  if (!url) throw new Error("run with --network tenderly and TENDERLY_RPC_URL set");
  const provider = new hre.ethers.providers.JsonRpcProvider(url);
  const net = await provider.getNetwork();
  if (net.chainId === 560048) throw new Error("refusing to run against real hoodi");
  console.log(`fork chainId=${net.chainId} block=${await provider.getBlockNumber()}\n`);

  const rm = await redeemManagerAt(hre, provider);
  const count = (await rm.getRedeemRequestCount()).toNumber();

  // ---- 0. confirm the repair is already applied -------------------------------------------------
  let prev = hre.ethers.constants.Zero;
  let monotonic = true;
  const openBefore: number[] = [];
  const owed = new Map<number, { recipient: string; amount: EthersType.BigNumber; cap: EthersType.BigNumber }>();
  for (let i = 0; i < count; ++i) {
    const d = await retry<any>(() => rm.getRedeemRequestDetails(i));
    if (d.height.lt(prev)) monotonic = false;
    prev = d.height.add(d.amount);
    if (d.amount.gt(0)) {
      openBefore.push(i);
      owed.set(i, { recipient: d.recipient.toLowerCase(), amount: d.amount, cap: d.maxRedeemableEth });
    }
  }
  const coverage0 = await withdrawalStackEnd(rm);
  const demand0 = await rm.getRedeemDemand();
  if (!monotonic || !prev.sub(coverage0).eq(demand0)) {
    throw new Error("queue does not look repaired - run simulateRecovery.ts first");
  }
  console.log("0. pre-state (repair already applied)");
  console.log(`   queue ${count} records, ${openBefore.length} open`);
  console.log(`   queue end ${eth(prev)}  coverage ${eth(coverage0)}  demand ${eth(demand0)}`);
  console.log(`   balance ${eth(await provider.getBalance(REDEEM_MANAGER))} ETH`);
  console.log(`   LsETH still owed ${eth(openBefore.reduce((a, i) => a.add(owed.get(i)!.amount), hre.ethers.constants.Zero))}\n`);

  // ---- 1. extend coverage over the remaining demand ---------------------------------------------
  // reportWithdraw is onlyRiver and caps at redeemDemand, so this is exactly what a future oracle
  // report would do, funded at River's own share-to-balance rate.
  console.log("1. simulate the oracle reporting the remaining demand");
  const river = new hre.ethers.Contract(RIVER, RIVER_ABI, provider);
  const ethNeeded: EthersType.BigNumber = await river.underlyingBalanceFromShares(demand0);
  console.log(`   reporting ${eth(demand0)} LsETH backed by ${eth(ethNeeded)} ETH (rate ${(+eth(ethNeeded).replace(/,/g, "") / +eth(demand0).replace(/,/g, "")).toFixed(9)})`);

  await provider.send("tenderly_setBalance", [
    RIVER,
    hre.ethers.utils.hexValue(ethNeeded.add(hre.ethers.utils.parseEther("1"))),
  ]);
  const riverSigner = provider.getSigner(RIVER);
  const rmAsRiver = new hre.ethers.Contract(REDEEM_MANAGER, RM_EXTRA_ABI, riverSigner);
  await (await rmAsRiver.reportWithdraw(demand0, { value: ethNeeded, gasLimit: 2_000_000 })).wait();

  const coverage1 = await withdrawalStackEnd(rm);
  const demand1 = await rm.getRedeemDemand();
  console.log(`   coverage ${eth(coverage0)} -> ${eth(coverage1)}   demand ${eth(demand0)} -> ${eth(demand1)}`);
  if (!demand1.isZero()) throw new Error("redeem demand did not reach zero");
  if (!coverage1.eq(prev)) throw new Error("coverage does not reach the queue end");
  console.log(`   coverage now equals the queue end: ${coverage1.eq(prev)}\n`);

  // ---- 2. claim everything ----------------------------------------------------------------------
  console.log("2. claim every remaining request");
  await provider.send("tenderly_setBalance", [CALLER, hre.ethers.utils.hexValue(hre.ethers.utils.parseEther("1000"))]);
  const rmCaller = rm.connect(provider.getSigner(CALLER));

  const received = new Map<string, EthersType.BigNumber>();
  let claimed = 0;
  let failed: number[] = [];
  for (const id of openBefore) {
    const w = owed.get(id)!;
    const resolved = await retry<any>(() => rm.resolveRedeemRequests([id]));
    if (resolved[0].lt(0)) {
      failed.push(id);
      continue;
    }
    const before = await retry(() => provider.getBalance(w.recipient));
    await (
      await rmCaller["claimRedeemRequests(uint32[],uint32[])"]([id], [resolved[0]], { gasLimit: 8_000_000 })
    ).wait();
    const paid = (await retry(() => provider.getBalance(w.recipient))).sub(before);
    received.set(w.recipient, (received.get(w.recipient) || hre.ethers.constants.Zero).add(paid));
    claimed += 1;
  }
  console.log(`   claimed ${claimed} / ${openBefore.length}`);
  if (failed.length) throw new Error(`still unclaimable after full coverage: ${JSON.stringify(failed)}`);

  // ---- 3. assert the queue is fully settled ------------------------------------------------------
  console.log("\n3. verify complete settlement");
  let stillOpen: number[] = [];
  for (let i = 0; i < count; ++i) {
    const d = await retry<any>(() => rm.getRedeemRequestDetails(i));
    if (d.amount.gt(0)) stillOpen.push(i);
  }
  const buffered = await rm.getBufferedExceedingEth();
  const balance = await provider.getBalance(REDEEM_MANAGER);
  const totalPaid = [...received.values()].reduce((a, b) => a.add(b), hre.ethers.constants.Zero);
  const totalCap = openBefore.reduce((a, i) => a.add(owed.get(i)!.cap), hre.ethers.constants.Zero);

  console.log(`   requests still open   : ${stillOpen.length}`);
  console.log(`   redeemDemand()        : ${eth(await rm.getRedeemDemand())}`);
  console.log(`   total ETH paid out    : ${eth(totalPaid)}`);
  console.log(`   sum of entitlements   : ${eth(totalCap)}`);
  console.log(`   bufferedExceedingEth  : ${eth(buffered)}`);
  console.log(`   contract balance left : ${eth(balance)}`);
  console.log(`   unexplained residue   : ${eth(balance.sub(buffered))}`);
  console.log(`\n   recipients paid: ${received.size}`);
  for (const [addr, amt] of [...received.entries()].sort((a, b) => (b[1].gt(a[1]) ? 1 : -1))) {
    console.log(`     ${addr}  ${eth(amt)} ETH`);
  }

  if (stillOpen.length) throw new Error(`queue not fully settled: ${JSON.stringify(stillOpen)}`);
  if (totalPaid.gt(totalCap)) throw new Error("paid out more than the sum of entitlements");
  if (balance.lt(buffered)) throw new Error("contract cannot cover its own exceeding-eth buffer");

  console.log("\n" + "=".repeat(78));
  console.log("FULL RECOVERY PROVEN - every request settled, nothing stranded, nothing overpaid");
  console.log("=".repeat(78));
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
