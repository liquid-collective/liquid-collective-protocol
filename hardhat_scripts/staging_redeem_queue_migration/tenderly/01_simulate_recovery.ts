import hre from "hardhat";
import { ethers as EthersType } from "ethers";
import {
  CLEAN_IMPL_1_3_0,
  REDEEM_MANAGER,
  REDEEM_MANAGER_PROXY_ADMIN,
  buildCorrectedQueue,
  encodeRepairCalldata,
  retry,
  historyProvider,
  redeemManagerAt,
  verifyQueue,
  withdrawalStackEnd,
  eth,
} from "../redeem_queue_repair";

// BS-4878: rehearse the full staging recovery on a Tenderly Virtual TestNet forked from hoodi.
//
//   npx hardhat run hardhat_scripts/staging_redeem_queue_migration/tenderly/01_simulate_recovery.ts --network tenderly
//
// Requires TENDERLY_RPC_URL to point at a Virtual TestNet forked from hoodi at (or near) head.
//
// Steps executed on the fork:
//    0. read pre-state and confirm the queue really is corrupted
//    1. TUPProxy.pause()                          from the proxy admin
//    2. confirm calls are blocked while paused
//    3. deploy RedeemManagerV1Recovery
//    4. upgradeToAndCall(recovery, repairRedeemQueue(...))
//    5. verify every request matches the intended payload
//    6. verify heights are monotonic and queue end - coverage == redeemDemand
//    7. upgradeTo(RedeemManagerV1) to drop the recovery surface
//    8. TUPProxy.unpause()
//    9. resolve and claim a restored request, checking the payout
//
// Nothing here touches real hoodi. Every transaction goes to the Virtual TestNet.

// Lowercase on purpose: ethers rejects mixed case that is not a valid EIP-55 checksum.
const DEPLOYER = "0x00000000000000000000000000000000beef4878";

const PROXY_ABI = [
  "function pause()",
  "function unpause()",
  "function paused() view returns (bool)",
  "function upgradeTo(address)",
  "function upgradeToAndCall(address,bytes)",
];

// Set BS4878_RESUME=1 to skip straight to verification when the repair has already been applied,
// e.g. after a transport failure mid-run. repairRedeemQueue is one-shot, so a plain re-run would
// otherwise be impossible without resetting the fork.
const RESUME = process.env.BS4878_RESUME === "1";

async function main() {
  const url = (hre.network.config as any).url as string;
  if (!url) throw new Error("network has no url - run with --network tenderly and set TENDERLY_RPC_URL");

  // Hardhat's LocalAccountsProvider rejects unsigned sends, so talk to the RPC directly and let the
  // Virtual TestNet impersonate. This mirrors deploy/hoodi/06_upgrade_v1_3_0_proxies.ts.
  const provider = new hre.ethers.providers.JsonRpcProvider(url);
  const net = await provider.getNetwork();
  console.log(`fork chainId=${net.chainId}  block=${await provider.getBlockNumber()}\n`);

  for (const who of [REDEEM_MANAGER_PROXY_ADMIN, DEPLOYER]) {
    await provider.send("tenderly_setBalance", [who, hre.ethers.utils.hexValue(hre.ethers.utils.parseEther("100"))]);
  }
  const admin = provider.getSigner(REDEEM_MANAGER_PROXY_ADMIN);
  const deployer = provider.getSigner(DEPLOYER);
  const proxyAsAdmin = new hre.ethers.Contract(REDEEM_MANAGER, PROXY_ABI, admin);

  const history = historyProvider(hre.ethers);
  const rm = await redeemManagerAt(hre, provider);

  console.log("=".repeat(78));
  console.log("0. pre-state");
  console.log("=".repeat(78));
  const zeroCall = { from: hre.ethers.constants.AddressZero };
  const count = (await rm.callStatic.getRedeemRequestCount(zeroCall)).toNumber();
  const demand = await rm.callStatic.getRedeemDemand(zeroCall);
  const coverage = await withdrawalStackEnd(rm);
  console.log(`  queue length ${count}   redeemDemand ${eth(demand)}   balance ${eth(await provider.getBalance(REDEEM_MANAGER))} ETH`);
  const absurd: number[] = [];
  for (let i = 0; i < Math.min(count, 86); ++i) {
    const d = await retry<any>(() => rm.callStatic.getRedeemRequestDetails(i, zeroCall));
    if (d.amount.gt(hre.ethers.utils.parseEther("1000000"))) absurd.push(i);
  }
  console.log(`  requests with absurd amounts (corruption present): ${absurd.length}`);
  if (!RESUME && absurd.length === 0) throw new Error("fork does not look corrupted - is this really hoodi?");

  console.log("\n  deriving the repair payload against the fork...");
  const rows = await buildCorrectedQueue(hre, history, provider);
  verifyQueue(rows, coverage, demand);
  console.log("  -> demand invariant holds against fork state");
  const calldata = encodeRepairCalldata(hre, rows);

  if (RESUME) {
    console.log("\n  BS4878_RESUME=1 - skipping steps 1-4, verifying the applied repair\n");
  }

  if (!RESUME) {
  console.log("\n" + "=".repeat(78));
  console.log("1. pause the proxy");
  console.log("=".repeat(78));
  await (await proxyAsAdmin.pause()).wait();
  console.log(`  paused: ${await proxyAsAdmin.paused()}`);

  console.log("\n" + "=".repeat(78));
  console.log("2. confirm calls are blocked while paused");
  console.log("=".repeat(78));
  let blocked = false;
  try {
    await rm.connect(provider.getSigner(DEPLOYER)).callStatic.getRedeemRequestCount({ from: DEPLOYER });
  } catch (e: any) {
    blocked = true;
    console.log(`  blocked: true  (${String(e.message).slice(0, 70)})`);
  }
  if (!blocked) throw new Error("proxy did not block calls while paused");

  console.log("\n" + "=".repeat(78));
  console.log("3. deploy RedeemManagerV1Recovery");
  console.log("=".repeat(78));
  const artifact = await hre.artifacts.readArtifact("RedeemManagerV1Recovery");
  const factory = new hre.ethers.ContractFactory(artifact.abi, artifact.bytecode, deployer);
  // Explicit limit: the tenderly network in hardhat.config caps gas at 5,000,000, and depositing
  // ~11.5 KB of runtime code alone costs roughly 2.3M.
  const recovery = await factory.deploy({ gasLimit: 10_000_000 });
  await recovery.deployed();
  console.log(`  recovery implementation at ${recovery.address}`);

  console.log("\n" + "=".repeat(78));
  console.log("4. upgradeToAndCall(recovery, repairRedeemQueue(...))");
  console.log("=".repeat(78));
  const receipt = await (await proxyAsAdmin.upgradeToAndCall(recovery.address, calldata, { gasLimit: 30_000_000 })).wait();
  console.log(`  status=${receipt.status} gas=${receipt.gasUsed.toString()}`);
  }

  console.log("\n" + "=".repeat(78));
  console.log("5. verify every request matches the intended payload");
  console.log("=".repeat(78));
  // The proxy is still paused, and it lets the zero address through so views keep working.
  const zeroCaller = { from: hre.ethers.constants.AddressZero };
  const mismatches: string[] = [];
  const restored: any[] = [];
  for (let i = 0; i < count; ++i) {
    const got = await retry<any>(() => rm.callStatic.getRedeemRequestDetails(i, zeroCaller));
    restored.push(got);
    const want = rows[i];
    if (!got.amount.eq(want.amount)) mismatches.push(`${i}.amount`);
    if (!got.maxRedeemableEth.eq(want.maxRedeemableEth)) mismatches.push(`${i}.maxRedeemableEth`);
    if (!got.height.eq(want.height)) mismatches.push(`${i}.height`);
    if (got.recipient.toLowerCase() !== want.recipient.toLowerCase()) mismatches.push(`${i}.recipient`);
    if (got.initiator.toLowerCase() !== want.initiator.toLowerCase()) mismatches.push(`${i}.initiator`);
  }
  console.log(`  requests checked: ${count}   mismatches: ${mismatches.length}`);
  if (mismatches.length) throw new Error(`repair did not restore: ${mismatches.slice(0, 12).join(", ")}`);
  console.log("  -> all fields restored exactly");

  console.log("\n" + "=".repeat(78));
  console.log("6. verify invariants");
  console.log("=".repeat(78));
  // Reuse the reads from step 5 rather than fetching all 125 again - Tenderly drops the connection
  // under long sequential call bursts.
  let prev = hre.ethers.constants.Zero;
  let monotonic = true;
  for (const d of restored) {
    if (d.height.lt(prev)) monotonic = false;
    prev = d.height.add(d.amount);
  }
  const demandAfter = await retry<any>(() => rm.callStatic.getRedeemDemand(zeroCaller));
  console.log(`  heights monotonic: ${monotonic}`);
  console.log(`  queue end ${eth(prev)} - coverage ${eth(coverage)} = ${eth(prev.sub(coverage))}`);
  console.log(`  redeemDemand                                    = ${eth(demandAfter)}`);
  console.log(`  invariant holds: ${prev.sub(coverage).eq(demandAfter)}`);
  if (!monotonic || !prev.sub(coverage).eq(demandAfter)) throw new Error("post-repair invariants failed");

  console.log("\n" + "=".repeat(78));
  console.log("7 & 8. restore the clean implementation and unpause");
  console.log("=".repeat(78));
  await (await proxyAsAdmin.upgradeTo(CLEAN_IMPL_1_3_0)).wait();
  await (await proxyAsAdmin.unpause()).wait();
  console.log(`  paused: ${await proxyAsAdmin.paused()}`);

  console.log("\n" + "=".repeat(78));
  console.log("9. claim a restored request end to end");
  console.log("=".repeat(78));
  const target = rows.findIndex((r) => r.amount.gt(0) && r.height.add(r.amount).lte(coverage));
  if (target < 0) {
    console.log("  no fully covered open request to claim - skipping");
  } else {
    const want = rows[target];
    console.log(`  claiming request ${target}: ${eth(want.amount)} LsETH to ${want.recipient}`);
    const resolved: EthersType.BigNumber[] = await rm.resolveRedeemRequests([target]);
    const eventId = resolved[0];
    if (eventId.lt(0)) throw new Error(`request ${target} resolved to ${eventId} - not claimable after repair`);
    console.log(`    resolves to withdrawal event ${eventId.toString()}`);
    const before = await provider.getBalance(want.recipient);
    await (await rm.connect(deployer)["claimRedeemRequests(uint32[],uint32[])"]([target], [eventId])).wait();
    const paid = (await provider.getBalance(want.recipient)).sub(before);
    console.log(`    recipient received ${eth(paid)} ETH (cap was ${eth(want.maxRedeemableEth)})`);
    console.log(`    remaining amount   ${eth((await rm.getRedeemRequestDetails(target)).amount)}`);
    if (paid.isZero()) throw new Error("claim paid nothing - recovery incomplete");
  }

  console.log("\n" + "=".repeat(78));
  console.log("REHEARSAL PASSED - the runbook works against real hoodi state");
  console.log("=".repeat(78));
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
