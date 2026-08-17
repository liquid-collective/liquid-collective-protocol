import "@nomiclabs/hardhat-ethers";
import { ethers as EthersType } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

// BS-4878: rebuild a correct redeem queue and prove it before writing it on chain.
//
// Everything the repair scripts share lives here: deriving the pre-upgrade queue two independent
// ways and requiring them to agree, assembling the corrected 125-record queue, checking the
// invariants the on-chain repair enforces, and ABI encoding the payload.
//
// The v1.3.0 upgrade script calls `initializeRedeemManagerV1_2` through `upgradeToAndCall`. On a
// deployment created fresh from v1.2.1 sources the redeem queue is already in RedeemQueueV2 layout
// while Version is still 1, so the `init(1)` guard passes and the V1 -> V2 migration is replayed. It
// reads 5 word records at a 4 word stride, so every record past index 0 is reassembled from fragments
// of its neighbours.
//
// Everything here is read-only. The only module that sends transactions is simulateRecovery.ts, and
// it only ever talks to a Tenderly Virtual TestNet.

export const HOODI_CHAIN_ID = 560048;

export const REDEEM_MANAGER = "0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7";
export const REDEEM_MANAGER_PROXY_ADMIN = "0x0C20959C12Eb226eC7DddC25109124AE850ED4BE";
export const CLEAN_IMPL_1_3_0 = "0xf155e40F0549f60842243F97794D5939c2E72F98";
export const RIVER = "0x0CA0c58b1986a55876552E0D9532C963625D5646";

export const DEPLOY_BLOCK = 307784;
export const UPGRADE_BLOCK = 3027299;

// Chain history is authoritative and lives on the real network. A Virtual TestNet forks state, so
// state reads go to the fork while log scans stay pointed here.
export const HISTORY_RPC = process.env.BS4878_HISTORY_RPC || "https://ethereum-hoodi-rpc.publicnode.com";

// An archive endpoint serving state at UPGRADE_BLOCK - 1. The default HISTORY_RPC is not archive, so
// this is separate. Known-good hoodi archive endpoints, all rate limited:
//   https://rpc.hoodi.ethpandaops.io
//   https://hoodi.drpc.org
//   https://hoodi.gateway.tenderly.co
export const ARCHIVE_RPC = process.env.BS4878_ARCHIVE_RPC || "https://rpc.hoodi.ethpandaops.io";

const LOG_CHUNK = 45000;

/// Retry transport failures. Tenderly drops the connection under long sequential call bursts, which
/// surfaces as ECONNRESET / SERVER_ERROR rather than a revert, so a plain retry clears it.
export async function retry<T>(fn: () => Promise<T>, attempts = 5, delayMs = 400): Promise<T> {
  let last: any;
  for (let i = 0; i < attempts; ++i) {
    try {
      return await fn();
    } catch (e: any) {
      const transport =
        e?.code === "SERVER_ERROR" ||
        e?.code === "TIMEOUT" ||
        e?.code === "NETWORK_ERROR" ||
        e?.error?.code === "ECONNRESET" ||
        e?.serverError?.code === "ECONNRESET";
      if (!transport) throw e;
      last = e;
      await new Promise((r) => setTimeout(r, delayMs * (i + 1)));
    }
  }
  throw last;
}

export interface RedeemRequest {
  amount: EthersType.BigNumber;
  maxRedeemableEth: EthersType.BigNumber;
  recipient: string;
  height: EthersType.BigNumber;
  initiator: string;
}

export interface Reconstructed extends RedeemRequest {
  id: number;
  size: EthersType.BigNumber;
  open: boolean;
}

export function historyProvider(ethers: typeof EthersType): EthersType.providers.JsonRpcProvider {
  return new ethers.providers.JsonRpcProvider(HISTORY_RPC);
}

export async function redeemManagerAt(
  hre: HardhatRuntimeEnvironment,
  provider: EthersType.providers.Provider,
  contractName = "RedeemManagerV1"
): Promise<EthersType.Contract> {
  const artifact = await hre.artifacts.readArtifact(contractName);
  return new hre.ethers.Contract(REDEEM_MANAGER, artifact.abi, provider);
}

/// Chunked getLogs, because public endpoints cap the block range.
async function scanLogs(
  contract: EthersType.Contract,
  filter: EthersType.EventFilter,
  from: number,
  to: number
): Promise<EthersType.Event[]> {
  const out: EthersType.Event[] = [];
  for (let start = from; start <= to; start += LOG_CHUNK) {
    const end = Math.min(start + LOG_CHUNK - 1, to);
    out.push(...(await retry(() => contract.queryFilter(filter, start, end))));
  }
  return out;
}

/// Rebuild the queue as it stood immediately before the BYOV upgrade.
///
/// `_claimRedeemRequest` holds `height + amount` constant and moves height forward as a request is
/// satisfied, so `height_now = height0 + size0 - remaining`. `maxRedeemableEth` is decremented by the
/// capped eth paid out, which ClaimedRedeemRequest reports as `ethAmount`.
///
/// `initiator` appears in no event. Pre-1.3.0 code set it to msg.sender, so it is River's address when
/// the request was routed through River.requestRedeem, else the EOA that sent the transaction.
export async function reconstructPreUpgrade(
  hre: HardhatRuntimeEnvironment,
  history: EthersType.providers.JsonRpcProvider
): Promise<Map<number, Reconstructed>> {
  const rm = await redeemManagerAt(hre, history);
  const cutoff = UPGRADE_BLOCK - 1;

  const requested = await scanLogs(rm, rm.filters.RequestedRedeem(), DEPLOY_BLOCK, cutoff);
  const claimed = await scanLogs(rm, rm.filters.ClaimedRedeemRequest(), DEPLOY_BLOCK, cutoff);

  const byId = new Map<number, any>();
  for (const ev of requested) {
    // RequestedRedeem's `amount` is the request's original size at creation.
    const { recipient, height, amount, maxRedeemableEth, id } = ev.args as any;
    byId.set(id, {
      id,
      recipient: recipient.toLowerCase(),
      height0: height,
      size: amount,
      maxEth0: maxRedeemableEth,
      endPos: height.add(amount),
      claimedEth: hre.ethers.constants.Zero,
      remaining: amount,
      txHash: ev.transactionHash,
    });
  }

  claimed.sort((a, b) => a.blockNumber - b.blockNumber || a.logIndex - b.logIndex);
  for (const ev of claimed) {
    const { redeemRequestId, ethAmount, remainingLsEthAmount } = ev.args as any;
    const r = byId.get(redeemRequestId);
    if (!r) continue;
    r.claimedEth = r.claimedEth.add(ethAmount);
    r.remaining = remainingLsEthAmount;
  }

  const txCache = new Map<string, string>();
  const out = new Map<number, Reconstructed>();
  for (const [id, r] of [...byId.entries()].sort((a, b) => a[0] - b[0])) {
    if (!txCache.has(r.txHash)) {
      const tx = await retry(() => history.getTransaction(r.txHash));
      const viaRiver = (tx.to || "").toLowerCase() === RIVER.toLowerCase();
      txCache.set(r.txHash, (viaRiver ? RIVER : tx.from).toLowerCase());
    }
    out.set(id, {
      id,
      amount: r.remaining,
      maxRedeemableEth: r.maxEth0.sub(r.claimedEth),
      recipient: r.recipient,
      height: r.endPos.sub(r.remaining),
      initiator: txCache.get(r.txHash)!,
      size: r.size,
      open: r.remaining.gt(0),
    });
  }
  return out;
}

/// Read the pre-upgrade queue directly from archive state at UPGRADE_BLOCK - 1.
///
/// This is the primary source. It beats the event reconstruction on two counts: nothing is derived,
/// and `initiator` is read rather than inferred - that field appears in no event, so
/// reconstructPreUpgrade has to guess it from whether the creating transaction targeted River.
export async function readPreUpgradeFromArchive(
  hre: HardhatRuntimeEnvironment,
  archive: EthersType.providers.JsonRpcProvider
): Promise<Map<number, RedeemRequest>> {
  const rm = await redeemManagerAt(hre, archive);
  const at = { blockTag: UPGRADE_BLOCK - 1 };
  const count = (await retry<any>(() => rm.getRedeemRequestCount(at))).toNumber();

  const out = new Map<number, RedeemRequest>();
  for (let i = 0; i < count; ++i) {
    const d = await retry<any>(() => rm.getRedeemRequestDetails(i, at));
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

/// Require the two independent derivations of the pre-upgrade queue to agree exactly.
///
/// The repair rewrites state irreversibly, so a single source is not enough. Any divergence means one
/// of the two is wrong and the run must stop rather than guess which.
export function assertSourcesAgree(
  archive: Map<number, RedeemRequest>,
  reconstructed: Map<number, Reconstructed>
): void {
  if (archive.size !== reconstructed.size) {
    throw new Error(`pre-upgrade source mismatch: archive has ${archive.size}, events have ${reconstructed.size}`);
  }
  const bad: string[] = [];
  for (const [id, a] of archive) {
    const r = reconstructed.get(id);
    if (!r) {
      bad.push(`${id}: missing from event reconstruction`);
      continue;
    }
    if (!a.amount.eq(r.amount)) bad.push(`${id}.amount`);
    if (!a.maxRedeemableEth.eq(r.maxRedeemableEth)) bad.push(`${id}.maxRedeemableEth`);
    if (!a.height.eq(r.height)) bad.push(`${id}.height`);
    if (a.recipient !== r.recipient.toLowerCase()) bad.push(`${id}.recipient`);
    if (a.initiator !== r.initiator.toLowerCase()) bad.push(`${id}.initiator`);
  }
  if (bad.length) {
    throw new Error(`archive and event reconstruction disagree on ${bad.length} field(s): ${bad.slice(0, 12).join(", ")}`);
  }
}

/// Claims booked against the corrupted region since the upgrade consumed a different request's
/// entitlement. The migration wrote index j from pre-migration words 4j..4j+3; when 4j is a multiple
/// of 5 those are exactly request 4j/5's amount, maxRedeemableEth, recipient and height, so the claim
/// must be netted against that request.
export async function claimNetting(
  hre: HardhatRuntimeEnvironment,
  history: EthersType.providers.JsonRpcProvider,
  legacyCount: number,
  toBlock: number
): Promise<Map<number, { lsETH: EthersType.BigNumber; eth: EthersType.BigNumber; from: number[] }>> {
  const rm = await redeemManagerAt(hre, history);
  const claimed = await scanLogs(rm, rm.filters.ClaimedRedeemRequest(), UPGRADE_BLOCK, toBlock);
  const netting = new Map<number, { lsETH: EthersType.BigNumber; eth: EthersType.BigNumber; from: number[] }>();
  for (const ev of claimed) {
    const { redeemRequestId, ethAmount, lsEthAmount } = ev.args as any;
    const id: number = redeemRequestId;
    if (id >= legacyCount) continue;
    if ((4 * id) % 5 !== 0) {
      throw new Error(`claim on corrupted id ${id} blends two records - attribute it manually`);
    }
    const source = (4 * id) / 5;
    const acc = netting.get(source) || {
      lsETH: hre.ethers.constants.Zero,
      eth: hre.ethers.constants.Zero,
      from: [],
    };
    acc.lsETH = acc.lsETH.add(lsEthAmount);
    acc.eth = acc.eth.add(ethAmount);
    acc.from.push(id);
    netting.set(source, acc);
  }
  return netting;
}

/// Assemble the full corrected queue.
///
/// Heights are never taken verbatim. They are derived from the end-position chain
/// `endPos[i] = endPos[i-1] + originalSize[i]`, then `height[i] = endPos[i] - amount[i]`, because
/// `height + amount` is the quantity the claim path holds invariant.
export async function buildCorrectedQueue(
  hre: HardhatRuntimeEnvironment,
  history: EthersType.providers.JsonRpcProvider,
  state: EthersType.providers.Provider
): Promise<RedeemRequest[]> {
  const rmState = await redeemManagerAt(hre, state);
  const rmHistory = await redeemManagerAt(hre, history);
  const count = (await rmState.getRedeemRequestCount()).toNumber();
  // Bound the scan by the state provider's height, not the live chain's. On a fork the two differ,
  // and scanning past the fork point would net claims the forked state has never seen.
  const head = Math.min(await state.getBlockNumber(), await history.getBlockNumber());

  // Two independent derivations of the pre-upgrade queue, required to agree before we rewrite state.
  // Archive is primary: nothing derived, and `initiator` read rather than inferred.
  const archive = new hre.ethers.providers.JsonRpcProvider(ARCHIVE_RPC);
  const legacyArchive = await readPreUpgradeFromArchive(hre, archive);
  const legacy = await reconstructPreUpgrade(hre, history);
  assertSourcesAgree(legacyArchive, legacy);

  const netting = await claimNetting(hre, history, legacy.size, head);

  // Original sizes for requests created after the upgrade.
  const postSizes = new Map<number, EthersType.BigNumber>();
  for (const ev of await scanLogs(rmHistory, rmHistory.filters.RequestedRedeem(), UPGRADE_BLOCK, head)) {
    const { amount, id } = ev.args as any;
    postSizes.set(id, amount);
  }

  const rows: RedeemRequest[] = [];
  const sizes: EthersType.BigNumber[] = [];
  for (let i = 0; i < count; ++i) {
    const rec = legacyArchive.get(i);
    if (rec) {
      let amount = rec.amount;
      let maxEth = rec.maxRedeemableEth;
      const net = netting.get(i);
      if (net) {
        amount = amount.sub(net.lsETH);
        maxEth = maxEth.sub(net.eth);
        if (amount.lt(0) || maxEth.lt(0)) {
          throw new Error(`netting request ${i} went negative - re-check the claim attribution`);
        }
      }
      rows.push({ amount, maxRedeemableEth: maxEth, recipient: rec.recipient, height: rec.height, initiator: rec.initiator });
      // Original size comes from the event reconstruction: archive state gives the remaining amount,
      // not the size at creation, and the end-position chain needs the latter.
      sizes.push(legacy.get(i)!.size);
    } else {
      const d = await retry<any>(() => rmState.getRedeemRequestDetails(i));
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
  for (let i = 0; i < rows.length; ++i) {
    end = end.add(sizes[i]);
    rows[i].height = end.sub(rows[i].amount);
  }
  return rows;
}

/// Retrieve the end position of the withdrawal stack, in the same cumulative LsETH space as the queue.
export async function withdrawalStackEnd(rm: EthersType.Contract): Promise<EthersType.BigNumber> {
  const count = (await rm.getWithdrawalEventCount()).toNumber();
  if (count === 0) return EthersType.BigNumber.from(0);
  const last = await rm.getWithdrawalEventDetails(count - 1);
  return last.height.add(last.amount);
}

/// Mirror the checks RedeemManagerV1Recovery.repairRedeemQueue performs, so a doomed transaction is
/// caught before it is sent. The decisive one is the demand check: RedeemDemand lives in its own slot
/// and was never written by the faulty migration, which makes it an independent witness that the
/// supplied queue geometry is correct.
export function verifyQueue(
  rows: RedeemRequest[],
  coverage: EthersType.BigNumber,
  redeemDemand: EthersType.BigNumber
): { queueEnd: EthersType.BigNumber; impliedDemand: EthersType.BigNumber } {
  let previousEnd = EthersType.BigNumber.from(0);
  for (let i = 0; i < rows.length; ++i) {
    const r = rows[i];
    if (r.recipient === EthersType.constants.AddressZero) throw new Error(`request ${i}: zero recipient`);
    if (r.initiator === EthersType.constants.AddressZero) throw new Error(`request ${i}: zero initiator`);
    if (r.height.lt(previousEnd)) {
      throw new Error(`request ${i}: height ${r.height} starts before previous end ${previousEnd}`);
    }
    const end = r.height.add(r.amount);
    if (i !== 0 && end.lte(previousEnd)) throw new Error(`request ${i}: non increasing end position`);
    previousEnd = end;
  }
  if (previousEnd.lt(coverage)) {
    throw new Error(`queue end ${previousEnd} below withdrawal coverage ${coverage}`);
  }
  const impliedDemand = previousEnd.sub(coverage);
  if (!impliedDemand.eq(redeemDemand)) {
    throw new Error(`DEMAND MISMATCH - implied ${impliedDemand} vs stored ${redeemDemand}; repair would revert`);
  }
  return { queueEnd: previousEnd, impliedDemand };
}

export function encodeRepairCalldata(
  hre: HardhatRuntimeEnvironment,
  rows: RedeemRequest[]
): string {
  const iface = new hre.ethers.utils.Interface([
    "function repairRedeemQueue((uint256 amount,uint256 maxRedeemableEth,address recipient,uint256 height,address initiator)[] _requests)",
  ]);
  return iface.encodeFunctionData("repairRedeemQueue", [
    rows.map((r) => [r.amount, r.maxRedeemableEth, r.recipient, r.height, r.initiator]),
  ]);
}

export function eth(v: EthersType.BigNumber): string {
  const s = EthersType.utils.formatEther(v);
  const [i, f = ""] = s.split(".");
  return `${BigInt(i).toLocaleString("en-US")}.${(f + "000000").slice(0, 6)}`;
}
