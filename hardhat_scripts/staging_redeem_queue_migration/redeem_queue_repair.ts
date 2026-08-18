import "@nomiclabs/hardhat-ethers";
import { ethers as EthersType } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

// BS-4878: rebuild a correct redeem queue and prove it before writing it on chain.
//
// The v1.3.0 upgrade called `initializeRedeemManagerV1_2` on a deployment whose queue was already in
// RedeemQueueV2 layout while Version was still 1, so the `init(1)` guard passed and the V1 -> V2
// migration replayed, reading 5 word records at a 4 word stride. Every record past index 0 is now
// reassembled from fragments of its neighbours.
//
// Shared by every script here: derive the pre-upgrade queue two independent ways and require them to
// agree, assemble the corrected queue, check the invariants the on-chain repair enforces, hash the
// queue the payload was built against, and ABI encode. Read-only; only 02_execute_repair.ts sends.

export const REDEEM_MANAGER = "0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7";
export const REDEEM_MANAGER_PROXY_ADMIN = "0x0C20959C12Eb226eC7DddC25109124AE850ED4BE";
export const CLEAN_IMPL_1_3_0 = "0xf155e40F0549f60842243F97794D5939c2E72F98";
export const RIVER = "0x0CA0c58b1986a55876552E0D9532C963625D5646";

export const DEPLOY_BLOCK = 307784;
export const UPGRADE_BLOCK = 3027299;

// Chain history is authoritative and lives on the real network, so log scans stay pointed here even
// when state reads go to a fork. ARCHIVE_RPC is separate because HISTORY_RPC is not an archive node;
// hoodi archives: rpc.hoodi.ethpandaops.io, hoodi.drpc.org, hoodi.gateway.tenderly.co.
export const HISTORY_RPC = process.env.BS4878_HISTORY_RPC || "https://ethereum-hoodi-rpc.publicnode.com";
export const ARCHIVE_RPC = process.env.BS4878_ARCHIVE_RPC || "https://rpc.hoodi.ethpandaops.io";

const LOG_CHUNK = 45000;
const FROM_ZERO = { from: EthersType.constants.AddressZero };

export interface RedeemRequest {
  amount: EthersType.BigNumber;
  maxRedeemableEth: EthersType.BigNumber;
  recipient: string;
  height: EthersType.BigNumber;
  initiator: string;
}

export interface Reconstructed extends RedeemRequest {
  size: EthersType.BigNumber;
  open: boolean;
}

/// Retry transport failures. Tenderly drops the connection under long call bursts, which surfaces as
/// ECONNRESET / SERVER_ERROR rather than a revert, so a plain retry clears it.
export async function retry<T>(fn: () => Promise<T>, attempts = 5, delayMs = 400): Promise<T> {
  let last: any;
  for (let i = 0; i < attempts; ++i) {
    try {
      return await fn();
    } catch (e: any) {
      const transport = ["SERVER_ERROR", "TIMEOUT", "NETWORK_ERROR"].includes(e?.code)
        || e?.error?.code === "ECONNRESET"
        || e?.serverError?.code === "ECONNRESET";
      if (!transport) throw e;
      last = e;
      await new Promise((r) => setTimeout(r, delayMs * (i + 1)));
    }
  }
  throw last;
}

export function historyProvider(ethers: typeof EthersType): EthersType.providers.JsonRpcProvider {
  return new ethers.providers.JsonRpcProvider(HISTORY_RPC);
}

export async function redeemManagerAt(
  hre: HardhatRuntimeEnvironment,
  provider: EthersType.providers.Provider
): Promise<EthersType.Contract> {
  const { abi } = await hre.artifacts.readArtifact("RedeemManagerV1");
  return new hre.ethers.Contract(REDEEM_MANAGER, abi, provider);
}

/// Chunked getLogs, because public endpoints cap the block range.
async function scanLogs(
  rm: EthersType.Contract,
  filter: EthersType.EventFilter,
  from: number,
  to: number
): Promise<EthersType.Event[]> {
  const out: EthersType.Event[] = [];
  for (let a = from; a <= to; a += LOG_CHUNK) {
    out.push(...(await retry(() => rm.queryFilter(filter, a, Math.min(a + LOG_CHUNK - 1, to)))));
  }
  return out;
}

/// Read one request, tolerating a paused proxy (TUPProxy lets the zero address through).
async function detail(rm: EthersType.Contract, i: number, overrides: any = FROM_ZERO): Promise<any> {
  return retry<any>(() => rm.callStatic.getRedeemRequestDetails(i, overrides));
}

async function requestCount(rm: EthersType.Contract, overrides: any = FROM_ZERO): Promise<number> {
  return (await retry<any>(() => rm.callStatic.getRedeemRequestCount(overrides))).toNumber();
}

/// Pre-upgrade queue, read straight from archive state. The primary source: nothing is derived, and
/// `initiator` is read rather than inferred - that field appears in no event.
export async function readPreUpgradeFromArchive(
  hre: HardhatRuntimeEnvironment,
  archive: EthersType.providers.JsonRpcProvider
): Promise<Map<number, RedeemRequest>> {
  const rm = await redeemManagerAt(hre, archive);
  const at = { blockTag: UPGRADE_BLOCK - 1 };
  const out = new Map<number, RedeemRequest>();
  for (let i = 0; i < (await requestCount(rm, at)); ++i) {
    const d = await detail(rm, i, at);
    out.set(i, {
      amount: d.amount,
      maxRedeemableEth: d.maxRedeemableEth,
      recipient: d.recipient.toLowerCase(),
      height: d.height,
      initiator: d.initiator.toLowerCase(),
    });
  }
  return out;
}

/// Pre-upgrade queue, replayed from events as an independent second opinion, and the only source of
/// each request's size at creation.
///
/// Claiming holds `height + amount` constant while moving height forward, so
/// `height = height0 + size0 - remaining`. `maxRedeemableEth` drops by the eth paid, which
/// ClaimedRedeemRequest reports. `initiator` is inferred: pre-1.3.0 code stored msg.sender, so it is
/// River when the request went through River.requestRedeem, else the sending EOA.
export async function reconstructPreUpgrade(
  hre: HardhatRuntimeEnvironment,
  history: EthersType.providers.JsonRpcProvider
): Promise<Map<number, Reconstructed>> {
  const rm = await redeemManagerAt(hre, history);
  const cutoff = UPGRADE_BLOCK - 1;
  const byId = new Map<number, any>();

  for (const ev of await scanLogs(rm, rm.filters.RequestedRedeem(), DEPLOY_BLOCK, cutoff)) {
    // RequestedRedeem's `amount` is the size at creation, not the remaining amount.
    const { recipient, height, amount, maxRedeemableEth, id: rawId } = ev.args as any;
    const id: number = typeof rawId === "number" ? rawId : rawId.toNumber();
    byId.set(id, {
      recipient: recipient.toLowerCase(),
      size: amount,
      maxEth0: maxRedeemableEth,
      endPos: height.add(amount),
      claimedEth: hre.ethers.constants.Zero,
      remaining: amount,
      txHash: ev.transactionHash,
    });
  }

  const claims = await scanLogs(rm, rm.filters.ClaimedRedeemRequest(), DEPLOY_BLOCK, cutoff);
  claims.sort((a, b) => a.blockNumber - b.blockNumber || a.logIndex - b.logIndex);
  for (const ev of claims) {
    const { redeemRequestId, ethAmount, remainingLsEthAmount } = ev.args as any;
    const r = byId.get(redeemRequestId);
    if (!r) continue;
    r.claimedEth = r.claimedEth.add(ethAmount);
    r.remaining = remainingLsEthAmount;
  }

  const initiators = new Map<string, string>();
  const out = new Map<number, Reconstructed>();
  for (const [id, r] of [...byId.entries()].sort((a, b) => a[0] - b[0])) {
    if (!initiators.has(r.txHash)) {
      const tx = await retry(() => history.getTransaction(r.txHash));
      const viaRiver = (tx.to || "").toLowerCase() === RIVER.toLowerCase();
      initiators.set(r.txHash, (viaRiver ? RIVER : tx.from).toLowerCase());
    }
    out.set(id, {
      amount: r.remaining,
      maxRedeemableEth: r.maxEth0.sub(r.claimedEth),
      recipient: r.recipient,
      height: r.endPos.sub(r.remaining),
      initiator: initiators.get(r.txHash)!,
      size: r.size,
      open: r.remaining.gt(0),
    });
  }
  return out;
}

/// The repair rewrites state irreversibly, so one source is not enough. Any divergence means one of
/// the two is wrong and the run must stop rather than guess which.
export function assertSourcesAgree(
  archive: Map<number, RedeemRequest>,
  events: Map<number, Reconstructed>
): void {
  if (archive.size !== events.size) {
    throw new Error(`pre-upgrade source mismatch: archive ${archive.size}, events ${events.size}`);
  }
  const bad: string[] = [];
  for (const [id, a] of archive) {
    const r = events.get(id);
    if (!r) {
      bad.push(`${id}: missing from event replay`);
      continue;
    }
    for (const f of ["amount", "maxRedeemableEth", "height"] as const) {
      if (!a[f].eq(r[f])) bad.push(`${id}.${f}`);
    }
    for (const f of ["recipient", "initiator"] as const) {
      if (a[f] !== r[f].toLowerCase()) bad.push(`${id}.${f}`);
    }
  }
  if (bad.length) {
    throw new Error(`archive and event replay disagree on ${bad.length} field(s): ${bad.slice(0, 12).join(", ")}`);
  }
}

/// A claim booked against the corrupted region consumed a different request's entitlement: the
/// migration wrote index j from pre-migration words 4j..4j+3, so when 4j divides by 5 those are
/// exactly request 4j/5's record and the claim nets against that request instead.
export async function claimNetting(
  hre: HardhatRuntimeEnvironment,
  history: EthersType.providers.JsonRpcProvider,
  legacyCount: number,
  toBlock: number
): Promise<Map<number, { lsETH: EthersType.BigNumber; eth: EthersType.BigNumber; from: number[] }>> {
  const rm = await redeemManagerAt(hre, history);
  const netting = new Map<number, { lsETH: EthersType.BigNumber; eth: EthersType.BigNumber; from: number[] }>();
  for (const ev of await scanLogs(rm, rm.filters.ClaimedRedeemRequest(), UPGRADE_BLOCK, toBlock)) {
    const { redeemRequestId: id, ethAmount, lsEthAmount } = ev.args as any;
    if (id >= legacyCount) continue;
    if ((4 * id) % 5 !== 0) throw new Error(`claim on corrupted id ${id} blends two records - attribute it manually`);
    const source = (4 * id) / 5;
    const acc = netting.get(source)
      ?? { lsETH: hre.ethers.constants.Zero, eth: hre.ethers.constants.Zero, from: [] as number[] };
    acc.lsETH = acc.lsETH.add(lsEthAmount);
    acc.eth = acc.eth.add(ethAmount);
    acc.from.push(id);
    netting.set(source, acc);
  }
  return netting;
}

/// Assemble the corrected queue.
///
/// Heights are never copied. They come from the end-position chain
/// `endPos[i] = endPos[i-1] + size[i]`, then `height[i] = endPos[i] - amount[i]`, because
/// `height + amount` is what the claim path holds invariant. Copying stored heights would be wrong
/// for every settled or partially claimed request.
export async function buildCorrectedQueue(
  hre: HardhatRuntimeEnvironment,
  history: EthersType.providers.JsonRpcProvider,
  state: EthersType.providers.Provider
): Promise<RedeemRequest[]> {
  const rmState = await redeemManagerAt(hre, state);
  const rmHistory = await redeemManagerAt(hre, history);
  const count = await requestCount(rmState);
  // Bound by the state provider's height: on a fork it trails the live chain, and scanning past the
  // fork point would net claims the forked state has never seen.
  const head = Math.min(await state.getBlockNumber(), await history.getBlockNumber());

  const archive = await readPreUpgradeFromArchive(hre, new hre.ethers.providers.JsonRpcProvider(ARCHIVE_RPC));
  const events = await reconstructPreUpgrade(hre, history);
  assertSourcesAgree(archive, events);
  const netting = await claimNetting(hre, history, archive.size, head);

  const postSizes = new Map<number, EthersType.BigNumber>();
  for (const ev of await scanLogs(rmHistory, rmHistory.filters.RequestedRedeem(), UPGRADE_BLOCK, head)) {
    const { amount, id } = ev.args as any;
    postSizes.set(id, amount);
  }

  const rows: RedeemRequest[] = [];
  const sizes: EthersType.BigNumber[] = [];
  for (let i = 0; i < count; ++i) {
    const pre = archive.get(i);
    if (pre) {
      const net = netting.get(i);
      const amount = net ? pre.amount.sub(net.lsETH) : pre.amount;
      const maxRedeemableEth = net ? pre.maxRedeemableEth.sub(net.eth) : pre.maxRedeemableEth;
      if (amount.lt(0) || maxRedeemableEth.lt(0)) {
        throw new Error(`netting request ${i} went negative - re-check the claim attribution`);
      }
      rows.push({ ...pre, amount, maxRedeemableEth });
      // Archive gives the remaining amount; the chain needs the size at creation, which only the
      // event replay has.
      sizes.push(events.get(i)!.size);
    } else {
      // Created after the upgrade, so the record itself is sound and only its height is misplaced.
      const d = await detail(rmState, i);
      rows.push({
        amount: d.amount,
        maxRedeemableEth: d.maxRedeemableEth,
        recipient: d.recipient.toLowerCase(),
        height: d.height,
        initiator: d.initiator.toLowerCase(),
      });
      const size = postSizes.get(i);
      if (!size) throw new Error(`no RequestedRedeem event for post-upgrade request ${i}`);
      sizes.push(size);
    }
  }

  let end = hre.ethers.constants.Zero;
  rows.forEach((r, i) => {
    end = end.add(sizes[i]);
    r.height = end.sub(r.amount);
  });
  return rows;
}

/// End position of the withdrawal stack, in the same cumulative LsETH space as the queue.
export async function withdrawalStackEnd(rm: EthersType.Contract): Promise<EthersType.BigNumber> {
  const count = (await retry<any>(() => rm.callStatic.getWithdrawalEventCount(FROM_ZERO))).toNumber();
  if (count === 0) return EthersType.BigNumber.from(0);
  const last = await retry<any>(() => rm.callStatic.getWithdrawalEventDetails(count - 1, FROM_ZERO));
  return last.height.add(last.amount);
}

/// Mirror of the checks repairRedeemQueue performs, so a doomed transaction is caught before it is
/// sent. The decisive one is the demand check: RedeemDemand sits in its own slot and was never written
/// by the faulty migration, which makes it an independent witness that the geometry is right.
export function verifyQueue(
  rows: RedeemRequest[],
  coverage: EthersType.BigNumber,
  redeemDemand: EthersType.BigNumber
): { queueEnd: EthersType.BigNumber; impliedDemand: EthersType.BigNumber } {
  let previousEnd = EthersType.BigNumber.from(0);
  rows.forEach((r, i) => {
    if (r.recipient === EthersType.constants.AddressZero) throw new Error(`request ${i}: zero recipient`);
    if (r.initiator === EthersType.constants.AddressZero) throw new Error(`request ${i}: zero initiator`);
    if (r.height.lt(previousEnd)) {
      throw new Error(`request ${i}: height ${r.height} starts before previous end ${previousEnd}`);
    }
    const end = r.height.add(r.amount);
    if (i !== 0 && end.lte(previousEnd)) throw new Error(`request ${i}: non increasing end position`);
    previousEnd = end;
  });
  if (previousEnd.lt(coverage)) throw new Error(`queue end ${previousEnd} below coverage ${coverage}`);
  const impliedDemand = previousEnd.sub(coverage);
  if (!impliedDemand.eq(redeemDemand)) {
    throw new Error(`DEMAND MISMATCH - implied ${impliedDemand} vs stored ${redeemDemand}; repair would revert`);
  }
  return { queueEnd: previousEnd, impliedDemand };
}

/// Hash the queue exactly as RedeemManagerV1Recovery._currentQueueHash does. The repair refuses to run
/// unless this still matches, so a claim landing between building the payload and sending it is
/// rejected rather than silently replayed - which is why no pause is needed. Field order must not
/// drift from the Solidity side.
export async function currentQueueHash(
  hre: HardhatRuntimeEnvironment,
  rm: EthersType.Contract
): Promise<string> {
  // Read the count once. In the loop condition it was re-read every iteration, doubling the request
  // volume and getting public endpoints to drop the connection part way through.
  const count = await requestCount(rm);
  let acc = hre.ethers.constants.HashZero;
  for (let i = 0; i < count; ++i) {
    const d = await detail(rm, i);
    acc = hre.ethers.utils.solidityKeccak256(
      ["bytes32", "uint256", "uint256", "address", "uint256", "address"],
      [acc, d.amount, d.maxRedeemableEth, d.recipient, d.height, d.initiator]
    );
  }
  return acc;
}

export function encodeRepairCalldata(
  hre: HardhatRuntimeEnvironment,
  rows: RedeemRequest[],
  expectedQueueHash: string
): string {
  const iface = new hre.ethers.utils.Interface([
    "function repairRedeemQueue((uint256 amount,uint256 maxRedeemableEth,address recipient,uint256 height,address initiator)[] _requests,bytes32 _expectedQueueHash)",
  ]);
  return iface.encodeFunctionData("repairRedeemQueue", [
    rows.map((r) => [r.amount, r.maxRedeemableEth, r.recipient, r.height, r.initiator]),
    expectedQueueHash,
  ]);
}

export function eth(v: EthersType.BigNumber): string {
  const [i, f = ""] = EthersType.utils.formatEther(v).split(".");
  const sign = i.startsWith("-") ? "-" : "";
  return `${sign}${BigInt(i.replace("-", "")).toLocaleString("en-US")}.${(f + "000000").slice(0, 6)}`;
}
