import "@nomiclabs/hardhat-ethers";
import { ethers as EthersType } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

// BS-4878 shared helpers.
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

const LOG_CHUNK = 45000;

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
    out.push(...(await contract.queryFilter(filter, start, end)));
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
      const tx = await history.getTransaction(r.txHash);
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
  const head = await history.getBlockNumber();

  const legacy = await reconstructPreUpgrade(hre, history);
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
    const rec = legacy.get(i);
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
      sizes.push(rec.size);
    } else {
      const d = await rmState.getRedeemRequestDetails(i);
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
