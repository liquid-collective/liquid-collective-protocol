---
shaping: true
---

# Pectra Upgrade — Shaping

## Requirements (R)

| ID | Requirement | Status |
|----|-------------|--------|
| **R0** | **Validator Consolidation (TVS):** External validators can consolidate into LC validators via EIP-7251 and receive LsETH | Core goal |
| **R1** | **Partial Exits:** LC can withdraw excess balance above 32 ETH from validators without full exit (EIP-7002) | Core goal |
| **R3** | **Allowlist-gated consolidation:** Only allowlisted addresses can initiate TVS consolidation | Must-have |
| **R4** | **Conversion rate integrity:** Consolidation buffer reconciliation with oracle must not introduce conversion rate errors | Must-have |
| **R6** | **Insolvency protection:** If a consolidation fails after LsETH minting, protocol must not become insolvent | Must-have |
| **R7** | **Keeper-driven exit strategy:** Automated keeper decides optimal partial vs full exit strategy | Must-have |
| **R10** | **Remove 32 ETH / validator count from accounting:** No accounting logic should depend on `DEPOSIT_SIZE` constant or validator counts. Track ETH amounts directly. (32 ETH remains valid for deposit mechanics only.) | Must-have |

---

## Shapes

### CURRENT: Hardcoded 32 ETH, Full-Exit-Only Model

| Part | Mechanism |
|------|-----------|
| **C1** | `DEPOSIT_SIZE = 32 ether` constant used for all deposit/balance math |
| **C2** | `_assetBalance()` adds `(depositedValidatorCount - clValidatorCount) * 32 ether` for in-flight validators |
| **C3** | `ConsensusLayerDepositManager` deposits exactly 32 ETH per validator via beacon deposit contract |
| **C4** | Oracle reports aggregate `validatorsBalance` + `validatorsCount` — no per-validator granularity |
| **C5** | Exit flow: operator exit request → full CL exit → funds to Withdraw contract → pulled by oracle report |
| **C6** | Pre-exiting balance: `requestedExitsCount * DEPOSIT_SIZE` (assumes 32 ETH per exit) |
| **C7** | Allowlist: bitmask system with DENY/DEPOSIT/REDEEM masks on Allowlist.1.sol |
| **C8** | BYOV: Keeper provides `OperatorAllocation[]` for explicit per-operator validator distribution |

---

### A: Consolidation Buffer + EL-Triggered Partial Exits

Extend existing contracts. Track pending consolidations in a buffer variable reconciled against the oracle's aggregate CL balance — no per-validator EB tracking. Add EL-triggered partial exits via EIP-7002.

| Part | Mechanism | Flag |
|------|-----------|:----:|
| **A1** | **Consolidation buffer:** New `PendingConsolidationBalance` storage variable on River. Incremented when keeper executes consolidation. Decremented when oracle reports new `validatorsConsolidatedBalance` delta. Follows same cumulative/non-decreasing pattern as `validatorsSkimmedBalance` and `validatorsExitedBalance`. | |
| **A2** | **Modified `_assetBalance()`:** Add `PendingConsolidationBalance` to total asset balance (`validatorsBalance + BalanceToDeposit + CommittedBalance + BalanceToRedeem + PendingConsolidationBalance + inFlightBalance`). When oracle reconciles, consolidated ETH moves from buffer into `validatorsBalance` — net `_assetBalance()` change = 0 for consolidation, only rewards remain as delta. | |
| **A3** | **Consolidation entry point (two-step, keeper-attested):** Step 1: User calls `requestConsolidation(sourcePubkey, targetPubkey)` — allowlist-checked (`CONSOLIDATION_MASK`), records `ConsolidationRequest{source, target, recipient, status: REQUESTED}`. Step 2: Keeper calls `executeConsolidation(requestId, expectedBalance)` — keeper reads source validator's CL balance, records `expectedBalance`, atomically increments `PendingConsolidationBalance += expectedBalance`, mints LsETH to recipient at current conversion rate, submits consolidation request to CL system contract. See [spike-consolidation-entry-point.md](spike-consolidation-entry-point.md). | |
| **A4** | **Oracle reconciliation:** New `validatorsConsolidatedBalance` field in `ConsensusLayerReport` (cumulative, non-decreasing). In `setConsensusLayerData`: compute `consolidatedDelta = new - old`, reduce `PendingConsolidationBalance` by delta. This happens after `_pullCLFunds` and before `postReportUnderlyingBalance = _assetBalance()`, so consolidation amount cancels out in the delta and bounds check sees only rewards. See [spike-buffer-reconciliation.md](spike-buffer-reconciliation.md). | |
| **A5** | **LsETH minting on consolidation:** Minted atomically in keeper's `executeConsolidation()` call. At this point `PendingConsolidationBalance` is already incremented in the same tx, so `_assetBalance()` accounts for the incoming ETH and the conversion rate is correct. Amount is keeper-attested (read from CL data), not user-provided. | |
| **A6** | **Partial exit via EIP-7002:** Keeper calls `River.requestExits()` with a mix of partial + full exits. River routes partial exits through Withdraw contract → EIP-7002 system contract (Withdraw is the withdrawal credentials address). New `PendingPartialExitBalance` storage variable tracks requested partial exit ETH not yet received. Oracle reports partial exit funds via new `validatorsPartiallyExitedBalance` field (cumulative, non-decreasing). Funds arrive at Withdraw → pulled by River → `BalanceToRedeem`. See [spike-partial-exits.md](spike-partial-exits.md). | |
| **A7** | **Keeper exit strategy:** Keeper calculates shortfall (`redeemDemandInEth - availableBalance`). Step 1: Fill shortfall with partial exits from validators with excess >32 ETH (sorted by excess descending, skip if EIP-7002 fee too high). Step 2: If shortfall remains, request full exits for the remainder via existing OperatorsRegistry flow. Partial exits preferred: faster (~minutes vs ~27hrs), cheaper (no new validator needed), preserves validator count, sub-32 ETH granularity. See [spike-partial-exits.md](spike-partial-exits.md). | |
| **A8** | 🟡 **Insolvency protection (two layers):** **Prevention:** Keeper validates source validator CL state before executing. Admin-configurable caps on single consolidation amount and total `PendingConsolidationBalance`. Allowlist vetting. **Detection:** Oracle reports `failedConsolidationIds[]` when source exits without balance transfer. Timeout fallback: consolidations pending > `MAX_CONSOLIDATION_DURATION` (e.g., 7 days) are flagged. **Recovery:** `PendingConsolidationBalance` written down by failed amount → `_assetBalance()` drops → loss socialized. Existing CoverageFund mechanism handles recovery: insurance/treasury donates lost amount, oracle pulls gradually via `availableAmountToUpperBound`. No new recovery mechanism needed — same pattern as slashing. See [spike-insolvency-protection.md](spike-insolvency-protection.md). | |
| **A9** | 🟡 **ETH-based accounting (remove 32 ETH / count dependencies):** (1) New `InFlightDepositBalance` storage — incremented by 32 ETH on each deposit, decremented by `newValidatorCount * 32 ETH` when oracle reports activation. Replaces `(depositedCount - clCount) * 32` in `_assetBalance()`. (2) New `PendingFullExitBalance` storage — incremented by keeper-provided actual validator balance on full exit request, decremented when oracle reports exited funds. Combined with `PendingPartialExitBalance`: `preExitingBalance = PendingFullExitBalance + PendingPartialExitBalance`. (3) ETH-based exit demand: `demandExitBalance(ethAmount)` replaces `demandValidatorExits(count)`. Keeper fills demand using actual CL balances. `DEPOSIT_SIZE` retained only for deposit mechanics. See [spike-eth-based-accounting.md](spike-eth-based-accounting.md). | |

---

## A3: Consolidation Entry Point Alternatives

Three alternatives were evaluated in the spike. See [spike-consolidation-entry-point.md](spike-consolidation-entry-point.md) for full details.

| Req | Requirement | Status | A3-A | A3-B | A3-C |
|-----|-------------|--------|------|------|------|
| **R0** | External validators can consolidate into LC validators and receive LsETH | Core goal | ✅ | ✅ | ✅ |
| **R3** | Only allowlisted addresses can initiate TVS consolidation | Must-have | ✅ | ✅ | ✅ |
| **R4** | Buffer reconciliation must not introduce conversion rate errors | Must-have | ❌ | ✅ | ✅ |

**Notes:**
- **A3-A** (user-initiated, immediate mint): User provides `expectedBalance` — could be wrong/malicious. Relies entirely on oracle reconciliation + A8 after the fact. Fails R4 because a lying user inflates `_assetBalance()` immediately.
- **A3-B** (keeper-attested, two-step): Keeper reads CL state, provides correct balance. Minting + buffer increment atomic. **Selected** — consistent with BYOV pattern (keeper already trusted for deposits).
- **A3-C** (oracle-confirmed, delayed): Safest but delayed minting (waits for oracle report). Adds minting complexity inside `setConsensusLayerData`. Rejected — UX too slow.

**Selected: A3-B** — Keeper-attested two-step consolidation.

---

## Fit Check: R × A

| Req | Requirement | Status | A |
|-----|-------------|--------|---|
| **R0** | External validators can consolidate into LC validators via EIP-7251 and receive LsETH | Core goal | ✅ |
| **R1** | LC can withdraw excess balance above 32 ETH without full exit (EIP-7002) | Core goal | ✅ |
| **R3** | Only allowlisted addresses can initiate TVS consolidation | Must-have | ✅ |
| **R4** | Consolidation buffer reconciliation with oracle must not introduce conversion rate errors | Must-have | ✅ |
| **R6** | If a consolidation fails after LsETH minting, protocol must not become insolvent | Must-have | 🟡 ✅ |
| **R7** | Automated keeper decides optimal partial vs full exit strategy | Must-have | ✅ |
| **R10** | No accounting logic depends on `DEPOSIT_SIZE` constant or validator counts | Must-have | 🟡 ✅ |

**Notes:**
- R0 ✅: A1-A5 fully resolved. Keeper-attested two-step consolidation with atomic mint + buffer increment.
- R1 ✅: A6 resolved — partial exits route through Withdraw → EIP-7002 system contract. See [spike-partial-exits.md](spike-partial-exits.md).
- R3 ✅: `CONSOLIDATION_MASK` on allowlist, checked at `requestConsolidation()`.
- R4 ✅: Buffer reconciliation resolved. See [spike-buffer-reconciliation.md](spike-buffer-reconciliation.md).
- R6 🟡✅: A8 unflagged — two-layer protection: prevention (keeper validation, caps, allowlist) + recovery (oracle/timeout detection → buffer writedown → CoverageFund backstop). Uses existing slashing recovery pattern. See [spike-insolvency-protection.md](spike-insolvency-protection.md).
- R7 ✅: A7 resolved — keeper prefers partial exits, falls back to full exits. See [spike-partial-exits.md](spike-partial-exits.md).
- R10 🟡✅: A9 unflagged — three replacements: `InFlightDepositBalance` (in-flight deposits), `PendingFullExitBalance` (pre-exiting), `demandExitBalance` (exit demand). `DEPOSIT_SIZE` retained for deposit mechanics only. See [spike-eth-based-accounting.md](spike-eth-based-accounting.md).

**All requirements pass. Shape A fully resolved.**

---

## Contract Changes Summary

| Contract | Changes |
|----------|---------|
| **River.1.sol** | New `_assetBalance()` with `PendingConsolidationBalance`. New `requestConsolidation()`, `executeConsolidation()`, `requestExits()` (partial+full), `writeDownFailedConsolidation()`. Modified `_requestExitsBasedOnRedeemDemandAfterRebalancings()` with `PendingPartialExitBalance`. Modified `setConsensusLayerData` with consolidation reconciliation + partial exit reconciliation. |
| **Withdraw.1.sol** | New `requestWithdrawal(pubkey, amountInGwei)` — calls EIP-7002 system contract. |
| **Allowlist.1.sol** | New `CONSOLIDATION_MASK = 0x8` (bit 4). |
| **IOracleManager.1.sol** | `ConsensusLayerReport` extended with `validatorsConsolidatedBalance`, `validatorsPartiallyExitedBalance`, `failedConsolidationIds[]`. `StoredConsensusLayerReport` extended with `validatorsConsolidatedBalance`, `validatorsPartiallyExitedBalance`. |
| **OperatorsRegistry.1.sol** | Exit demand changes from count-based to ETH-based: `demandExitBalance(ethAmount)` replaces `demandValidatorExits(count)`. Keeper fills using actual validator balances. |
| **State (new)** | `PendingConsolidationBalance.sol`, `PendingPartialExitBalance.sol`, `PendingFullExitBalance.sol`, `InFlightDepositBalance.sol`, `CurrentExitDemandBalance.sol`, `ConsolidationRequests.sol`. |

## New Oracle Report Fields

| Field | Type | Pattern | Purpose |
|-------|------|---------|---------|
| `validatorsConsolidatedBalance` | `uint256` | Cumulative, non-decreasing | Track ETH consolidated into LC validators |
| `validatorsPartiallyExitedBalance` | `uint256` | Cumulative, non-decreasing | Track ETH withdrawn via EIP-7002 partial exits |
| `failedConsolidationIds` | `uint32[]` | Per-report | Report consolidations that failed on CL |

---

## Open Questions

1. ~~**Consolidation UX**~~ — ✅ Resolved. See [spike-consolidation-entry-point.md](spike-consolidation-entry-point.md).
2. ~~**Conversion rate protection**~~ — ✅ Resolved. See [spike-insolvency-protection.md](spike-insolvency-protection.md).
3. ~~**Partial exit fee economics**~~ — ✅ Resolved. See [spike-partial-exits.md](spike-partial-exits.md).
4. ~~**Buffer reconciliation mechanics**~~ — ✅ Resolved. See [spike-buffer-reconciliation.md](spike-buffer-reconciliation.md).
5. ~~**Pre-exiting balance with partial exits**~~ — ✅ Resolved. See [spike-partial-exits.md](spike-partial-exits.md).

## Spike Documents

1. [spike-buffer-reconciliation.md](spike-buffer-reconciliation.md) — How `PendingConsolidationBalance` integrates with oracle reporting
2. [spike-consolidation-entry-point.md](spike-consolidation-entry-point.md) — Two-step keeper-attested consolidation flow (A3-B selected)
3. [spike-partial-exits.md](spike-partial-exits.md) — EIP-7002 partial exits via Withdraw + keeper strategy
4. [spike-insolvency-protection.md](spike-insolvency-protection.md) — Failed consolidation detection, writedown, and CoverageFund recovery
