import * as fs from "fs";
import * as path from "path";
import hre from "hardhat";
import { ethers as EthersType } from "ethers";
import {
  CLEAN_IMPL_1_3_0,
  REDEEM_MANAGER,
  RedeemRequest,
  currentQueueHash,
  historyProvider,
  redeemManagerAt,
  retry,
  scanLogs,
  withdrawalStackEnd,
  eth,
} from "../redeem_queue_repair";

// BS-4878: after the repair, prove the on-chain queue is the queue we provided.
//
//   npx hardhat run hardhat_scripts/staging_redeem_queue_migration/hoodi/03_verify_queue.ts --network hoodi
//
// 02_execute_repair.ts already verifies before it restores the implementation, but that check lives
// inside the run that performed the write and only sees the moment right after it. This is the
// standalone, read-only version: it can be run by anyone, at any later block, without a key, and it
// reads the reviewed artifact from the repo rather than from the executing process's memory.
//
// "What we provided" is the calldata in the committed preflight artifact, decoded through the compiled
// recovery ABI - the actual bytes that were signed, not the human-readable diff beside them. The diff
// is checked against those bytes too, so a doctored artifact fails here.
//
// The queue moves after a repair: claims reduce `amount` and `maxRedeemableEth` and push `height`
// forward, and new requests get appended. So a later run cannot demand byte equality. What it demands
// instead is that every difference is one a claim could have made:
//
//   recipient, initiator          never change
//   height + amount               never changes - the claim path holds the end position constant
//   amount, maxRedeemableEth      only ever decrease
//
// Anything else means the repair did not land as reviewed. On real hoodi the drift is additionally
// reconciled against ClaimedRedeemRequest logs, so the amounts have to match the claims that actually
// happened rather than merely being plausible.
//
// Exits non-zero on any mismatch, and writes a dated report next to the preflight artifact.

const REAL_HOODI_CHAIN_ID = 560048;
const ARTIFACT_DIR = "hardhat_scripts/staging_redeem_queue_migration";
const EIP1967_IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

// TUPProxy blocks every caller but the zero address while paused, so all reads go from there.
const FROM_ZERO = { from: hre.ethers.constants.AddressZero };

type Status = "exact" | "claimed-since" | "MISMATCH";

interface Row extends RedeemRequest {
  endPosition: EthersType.BigNumber;
}

interface Comparison {
  id: number;
  status: Status;
  reasons: string[];
  claimedLsETH: EthersType.BigNumber;
  claimedEth: EthersType.BigNumber;
  provided: Row;
  onChain: Row;
}

function toRow(r: any): Row {
  return {
    amount: r.amount,
    maxRedeemableEth: r.maxRedeemableEth,
    recipient: r.recipient.toLowerCase(),
    height: r.height,
    initiator: r.initiator.toLowerCase(),
    endPosition: r.height.add(r.amount),
  };
}

function serialize(r: Row): Record<string, string> {
  return {
    amount: r.amount.toString(),
    maxRedeemableEth: r.maxRedeemableEth.toString(),
    recipient: r.recipient,
    height: r.height.toString(),
    initiator: r.initiator,
    endPosition: r.endPosition.toString(),
  };
}

/// Hash a set of records exactly as RedeemManagerV1Recovery._currentQueueHash does, so the provided
/// payload can be reduced to the same single value `currentQueueHash` reads off the chain. Field order
/// must not drift from the Solidity side.
function hashRows(rows: RedeemRequest[]): string {
  let acc = hre.ethers.constants.HashZero;
  for (const r of rows) {
    acc = hre.ethers.utils.solidityKeccak256(
      ["bytes32", "uint256", "uint256", "address", "uint256", "address"],
      [acc, r.amount, r.maxRedeemableEth, r.recipient, r.height, r.initiator]
    );
  }
  return acc;
}

/// Load the committed preflight artifact and recover the records that were actually submitted.
///
/// The calldata is the authority: it is what the Firewall transaction carried. `records[].intended` is
/// the reviewed rendering of it, so any disagreement between the two means the file no longer describes
/// what was sent and nothing downstream of it can be trusted.
function loadProvidedPayload(): {
  file: string;
  generatedAtBlock: number;
  generatedAtISO: string;
  preRepairQueueHash: string;
  provided: Row[];
} {
  const found = fs.readdirSync(ARTIFACT_DIR).filter((f) => /^preflight-\d+\.json$/.test(f));
  if (found.length !== 1) {
    throw new Error(`expected exactly one preflight-<block>.json in ${ARTIFACT_DIR}, found ${found.length}`);
  }
  const file = path.join(ARTIFACT_DIR, found[0]);
  const { calldata, expectedQueueHash, generatedAtBlock, generatedAtISO, records } = JSON.parse(
    fs.readFileSync(file, "utf8")
  );
  if (!calldata || !expectedQueueHash) throw new Error(`${file} is missing calldata or expectedQueueHash`);

  // Decode through the compiled ABI rather than fixed offsets, so the selector and tuple layout are
  // validated as well as the contents.
  const recoveryInterface = new hre.ethers.utils.Interface([
    "function repairRedeemQueue((uint256 amount,uint256 maxRedeemableEth,address recipient,uint256 height,address initiator)[] _requests,bytes32 _expectedQueueHash)",
  ]);
  const decoded = recoveryInterface.decodeFunctionData("repairRedeemQueue", calldata);
  if (decoded._expectedQueueHash.toLowerCase() !== expectedQueueHash.toLowerCase()) {
    throw new Error(
      `${file} is inconsistent: payload carries ${decoded._expectedQueueHash}, artifact says ${expectedQueueHash}`
    );
  }
  const provided: Row[] = decoded._requests.map((r: any) => toRow(r));

  // Cross-check the reviewed diff against the bytes it claims to describe.
  if (!Array.isArray(records) || records.length !== provided.length) {
    throw new Error(`${file}: payload has ${provided.length} records, diff lists ${records?.length}`);
  }
  const drifted: string[] = [];
  provided.forEach((p, id) => {
    const intended = records[id].intended;
    if (!p.amount.eq(intended.amount)) drifted.push(`${id}.amount`);
    if (!p.maxRedeemableEth.eq(intended.maxRedeemableEth)) drifted.push(`${id}.maxRedeemableEth`);
    if (!p.height.eq(intended.height)) drifted.push(`${id}.height`);
    if (p.recipient !== intended.recipient.toLowerCase()) drifted.push(`${id}.recipient`);
    if (p.initiator !== intended.initiator.toLowerCase()) drifted.push(`${id}.initiator`);
  });
  if (drifted.length) {
    throw new Error(`${file}: calldata and the reviewed diff disagree on ${drifted.slice(0, 12).join(", ")}`);
  }

  return { file, generatedAtBlock, generatedAtISO, preRepairQueueHash: expectedQueueHash, provided };
}

/// Claims booked since the artifact was built, per request id.
///
/// The lower bound is safe: the repair rejects any queue but the one the artifact was built against, so
/// no claim can have landed between generation and the repair itself. Everything this finds is therefore
/// post-repair activity.
async function claimsSince(
  history: EthersType.providers.JsonRpcProvider,
  fromBlock: number,
  toBlock: number
): Promise<Map<number, { lsETH: EthersType.BigNumber; eth: EthersType.BigNumber }>> {
  const rm = await redeemManagerAt(hre, history);
  const out = new Map<number, { lsETH: EthersType.BigNumber; eth: EthersType.BigNumber }>();
  for (const ev of await scanLogs(rm, rm.filters.ClaimedRedeemRequest(), fromBlock, toBlock)) {
    const { redeemRequestId, ethAmount, lsEthAmount } = ev.args as any;
    const id: number = typeof redeemRequestId === "number" ? redeemRequestId : redeemRequestId.toNumber();
    const acc = out.get(id) ?? { lsETH: hre.ethers.constants.Zero, eth: hre.ethers.constants.Zero };
    acc.lsETH = acc.lsETH.add(lsEthAmount);
    acc.eth = acc.eth.add(ethAmount);
    out.set(id, acc);
  }
  return out;
}

/// Classify one record against the one we provided.
///
/// Identity fields and the end position are absolutes. The two balances may only have moved down, and
/// they must have moved down together with the end position held - that is the shape a claim leaves.
function compare(id: number, provided: Row, onChain: Row): Comparison {
  const reasons: string[] = [];
  if (onChain.recipient !== provided.recipient) reasons.push("recipient");
  if (onChain.initiator !== provided.initiator) reasons.push("initiator");
  if (!onChain.endPosition.eq(provided.endPosition)) reasons.push("height+amount");
  if (onChain.amount.gt(provided.amount)) reasons.push("amount increased");
  if (onChain.maxRedeemableEth.gt(provided.maxRedeemableEth)) reasons.push("maxRedeemableEth increased");
  if (onChain.height.lt(provided.height)) reasons.push("height moved backwards");

  const claimedLsETH = provided.amount.sub(onChain.amount);
  const claimedEth = provided.maxRedeemableEth.sub(onChain.maxRedeemableEth);
  // ETH left the request but LsETH did not, or the reverse: no claim does that.
  if (reasons.length === 0 && claimedLsETH.isZero() !== claimedEth.isZero()) {
    reasons.push("one balance moved without the other");
  }

  const unchanged = claimedLsETH.isZero() && claimedEth.isZero() && onChain.height.eq(provided.height);
  return {
    id,
    status: reasons.length ? "MISMATCH" : unchanged ? "exact" : "claimed-since",
    reasons,
    claimedLsETH,
    claimedEth,
    provided,
    onChain,
  };
}

async function main() {
  const state = hre.ethers.provider;
  const chainId = (await state.getNetwork()).chainId;
  const isRealHoodi = chainId === REAL_HOODI_CHAIN_ID;
  const rm = await redeemManagerAt(hre, state);

  const block = await state.getBlockNumber();
  const timestamp = (await state.getBlock(block)).timestamp;
  console.log(
    `BS-4878 post-repair verification @ ${isRealHoodi ? "REAL HOODI" : `fork chainId ${chainId}`}` +
      ` block ${block} (${new Date(timestamp * 1000).toISOString()})\n`
  );

  const { file, generatedAtBlock, generatedAtISO, preRepairQueueHash, provided } = loadProvidedPayload();
  console.log(`provided payload ${file}`);
  console.log(`  ${provided.length} records, built at block ${generatedAtBlock} (${generatedAtISO})`);
  console.log(`  calldata agrees with the reviewed diff, and carries pre-repair hash ${preRepairQueueHash}\n`);

  // The repair was performed by a temporary implementation that 02 restores afterwards. If it is still
  // installed, that is the headline, whatever the queue looks like.
  const implementation = hre.ethers.utils.getAddress(
    `0x${(await state.getStorageAt(REDEEM_MANAGER, EIP1967_IMPL_SLOT)).slice(-40)}`
  );
  const implementationRestored = implementation.toLowerCase() === CLEAN_IMPL_1_3_0.toLowerCase();

  const count = (await retry<any>(() => rm.callStatic.getRedeemRequestCount(FROM_ZERO))).toNumber();
  if (count < provided.length) {
    throw new Error(`queue holds ${count} records but ${provided.length} were provided - the repair did not land`);
  }

  const onChain: Row[] = [];
  for (let id = 0; id < count; ++id) {
    onChain.push(toRow(await retry<any>(() => rm.callStatic.getRedeemRequestDetails(id, FROM_ZERO))));
  }

  const comparisons = provided.map((p, id) => compare(id, p, onChain[id]));
  const mismatched = comparisons.filter((c) => c.status === "MISMATCH");
  const claimedSince = comparisons.filter((c) => c.status === "claimed-since");

  // A single value proving byte equality, when nothing has been claimed and nothing appended.
  const providedQueueHash = hashRows(provided);
  const liveQueueHash = count === provided.length ? await currentQueueHash(hre, rm) : undefined;
  const byteExact = liveQueueHash !== undefined && liveQueueHash === providedQueueHash;

  // Requests created after the repair. Their contents are not ours to check, but they must extend the
  // queue rather than overlap it.
  const appended = onChain.slice(provided.length);
  const appendedProblems: string[] = [];
  let previousEnd = hre.ethers.constants.Zero;
  let monotonic = true;
  onChain.forEach((r, id) => {
    if (r.height.lt(previousEnd)) {
      monotonic = false;
      if (id >= provided.length) appendedProblems.push(`${id}: height ${r.height} starts before ${previousEnd}`);
    }
    previousEnd = r.endPosition;
  });

  // The demand check is the independent one: RedeemDemand lives in its own slot and was never touched by
  // the faulty migration or by the repair, so it can corroborate the queue's geometry from outside it.
  const coverage = await withdrawalStackEnd(rm);
  const redeemDemand = await rm.callStatic.getRedeemDemand(FROM_ZERO);
  const impliedDemand = previousEnd.gte(coverage) ? previousEnd.sub(coverage) : undefined;
  const demandHolds = impliedDemand !== undefined && impliedDemand.eq(redeemDemand);

  // Reconcile the drift with the claims that actually happened. On a fork the logs come from the real
  // chain, so fork-local claims (02_full_recovery.ts, the smoke test in 02_execute_repair.ts) are
  // invisible here and the reconciliation is reported but not enforced.
  const history = historyProvider(hre.ethers);
  const head = Math.min(block, await history.getBlockNumber());
  const claims = await claimsSince(history, generatedAtBlock, head);
  const unreconciled: string[] = [];
  for (const c of comparisons) {
    const claimed = claims.get(c.id) ?? { lsETH: hre.ethers.constants.Zero, eth: hre.ethers.constants.Zero };
    if (!claimed.lsETH.eq(c.claimedLsETH) || !claimed.eth.eq(c.claimedEth)) unreconciled.push(`${c.id}`);
  }

  console.log("queue vs the provided payload");
  console.log(`  records matching exactly              : ${comparisons.length - claimedSince.length - mismatched.length}/${provided.length}`);
  console.log(`  changed only by claims since          : ${claimedSince.length}`);
  console.log(`  MISMATCHED                            : ${mismatched.length}`);
  console.log(`  provided queue hash                   : ${providedQueueHash}`);
  console.log(
    `  live queue hash                       : ${liveQueueHash ?? `n/a (${appended.length} record(s) appended)`}` +
      `${byteExact ? "  -> byte exact" : ""}`
  );
  for (const c of mismatched.slice(0, 12)) {
    console.log(`    id ${c.id}: ${c.reasons.join(", ")}`);
    console.log(`      provided ${JSON.stringify(serialize(c.provided))}`);
    console.log(`      on chain ${JSON.stringify(serialize(c.onChain))}`);
  }
  for (const c of claimedSince) {
    console.log(`    id ${c.id}: claimed ${eth(c.claimedLsETH)} LsETH for ${eth(c.claimedEth)} ETH since the repair`);
  }

  console.log("\ninvariants");
  console.log(`  implementation                        : ${implementation}${implementationRestored ? "" : "  <- NOT RESTORED"}`);
  console.log(`  end positions non decreasing          : ${monotonic}`);
  console.log(`  queue end                             : ${eth(previousEnd)}`);
  console.log(`  withdrawal coverage                   : ${eth(coverage)}`);
  console.log(
    `  queueEnd - coverage ${impliedDemand ? eth(impliedDemand) : "n/a (queue end below coverage)"}` +
      ` == redeemDemand ${eth(redeemDemand)} : ${demandHolds}`
  );
  console.log(`  requests appended after the repair    : ${appended.length}`);
  console.log(
    `  drift reconciled with claim logs      : ${unreconciled.length === 0}` +
      `${unreconciled.length ? ` (ids ${unreconciled.slice(0, 12).join(", ")})` : ""}` +
      `${isRealHoodi ? "" : "  [advisory only: fork-local claims are not in the real chain's logs]"}`
  );

  const report = {
    verifiedAtBlock: block,
    verifiedAtISO: new Date(timestamp * 1000).toISOString(),
    chainId,
    realHoodi: isRealHoodi,
    redeemManager: REDEEM_MANAGER,
    payload: { file, generatedAtBlock, generatedAtISO, preRepairQueueHash, recordCount: provided.length },
    result: {
      exact: comparisons.length - claimedSince.length - mismatched.length,
      changedByClaims: claimedSince.length,
      mismatched: mismatched.length,
      providedQueueHash,
      liveQueueHash: liveQueueHash ?? null,
      byteExact,
    },
    invariants: {
      implementation,
      implementationRestored,
      endPositionsNonDecreasing: monotonic,
      queueEnd: previousEnd.toString(),
      withdrawalCoverage: coverage.toString(),
      impliedDemand: impliedDemand?.toString() ?? null,
      redeemDemand: redeemDemand.toString(),
      demandHolds,
      appendedAfterRepair: appended.length,
      appendedProblems,
      driftReconciledWithClaimLogs: unreconciled.length === 0,
      unreconciledIds: unreconciled,
    },
    records: comparisons.map((c) => ({
      id: c.id,
      status: c.status,
      reasons: c.reasons,
      claimedSinceRepair: { lsETH: c.claimedLsETH.toString(), eth: c.claimedEth.toString() },
      provided: serialize(c.provided),
      onChain: serialize(c.onChain),
    })),
    appendedRecords: appended.map((r, i) => ({ id: provided.length + i, ...serialize(r) })),
  };

  const out = `${ARTIFACT_DIR}/postcheck-${block}.json`;
  fs.writeFileSync(out, JSON.stringify(report, null, 2));
  console.log(`\nwrote ${out}`);

  // Fail on anything that says the repair is not the reviewed one. Log reconciliation only counts on the
  // real chain, where the logs are complete.
  const failures = [
    mismatched.length ? `${mismatched.length} record(s) do not match the provided payload` : null,
    monotonic ? null : "end positions are not non decreasing",
    demandHolds ? null : "queueEnd - coverage != redeemDemand",
    implementationRestored ? null : `implementation is ${implementation}, expected ${CLEAN_IMPL_1_3_0}`,
    isRealHoodi && unreconciled.length ? `drift on ${unreconciled.length} record(s) is not backed by claim logs` : null,
  ].filter(Boolean) as string[];

  if (failures.length) {
    console.error("\nVERIFICATION FAILED");
    for (const f of failures) console.error(`  ${f}`);
    process.exitCode = 1;
    return;
  }
  console.log(
    byteExact
      ? "\nVERIFIED - the queue is byte for byte the queue we provided"
      : `\nVERIFIED - the queue is the queue we provided, moved only by ${claimedSince.length} claim(s) since`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
