---
shaping: true
---

# A8 Spike: Insolvency Protection for Failed Consolidations

## Context

When a consolidation is executed (A3), LsETH is minted immediately and `PendingConsolidationBalance` is incremented. If the consolidation subsequently fails on CL (source validator exits but balance doesn't transfer to the target), the protocol has minted LsETH backed by ETH that never arrives. `PendingConsolidationBalance` stays inflated, `_assetBalance()` overstates the real value, and every LsETH holder is exposed to dilution.

We need a mechanism to detect failure, write down the buffer, and recover the loss.

## Goal

Determine the concrete mechanics of insolvency protection: how failure is detected, how the buffer is written down, how the loss is covered, and what the impact is on LsETH holders.

## Questions

| # | Question | Answer |
|---|----------|--------|
| **Q1** | How does the CoverageFund currently work? | Simple donation-based fund. Authorized entities (treasury, insurance) call `donate()` to deposit ETH. River pulls from it during oracle reports, after EL fees, if there's headroom under the `annualAprUpperBound`. Coverage funds go to `BalanceToDeposit` — no fee minted on them. Funds are pulled gradually across multiple reports due to the upper bound constraint. Designed for slashing recovery with a 365-day target for injection. |
| **Q2** | How can a consolidation fail? | Several failure modes: (1) CL rejects the consolidation request (source validator ineligible, target ineligible). (2) Source validator gets slashed during the consolidation window. (3) Source validator exits before balance transfers to target. (4) Unknown CL bug prevents transfer. In all cases: the source validator's balance doesn't arrive at the target LC validator, but LsETH has already been minted. |
| **Q3** | When can we detect failure? | The oracle can detect failure when: (1) The consolidation has been pending for longer than a maximum expected duration (timeout). After CL acceptance, balance transfer typically takes ~27 hours (exit queue). If no `validatorsConsolidatedBalance` increase is reported after N epochs (e.g., 2x the expected window), it's likely failed. (2) The oracle detects the source validator has exited without a corresponding consolidation transfer. The oracle has CL visibility and can match source exit events to pending consolidation records. |
| **Q4** | What happens between failure and recovery? | `PendingConsolidationBalance` remains inflated → `_assetBalance()` is higher than actual → conversion rate is inflated → all LsETH holders get slightly less ETH per share than they should. The consolidator's LsETH is worth more than the ETH they actually contributed. This is the **insolvency window**. |
| **Q5** | Can we burn the consolidator's LsETH to recover? | Technically possible but undesirable: (1) The consolidator may have already transferred or sold the LsETH. (2) Forced burning would require tracking per-consolidation LsETH recipients and having admin authority to burn — introduces censorship/seizure risk. (3) Institutional users would not accept a protocol that can seize their tokens. **Not recommended.** |
| **Q6** | How does the CoverageFund recover the loss? | Same mechanism as slashing recovery: (1) Admin/oracle writes down `PendingConsolidationBalance` by the failed amount. (2) `_assetBalance()` drops → conversion rate drops (loss socialized across all holders). (3) Alluvial/insurance donates the lost amount to CoverageFund. (4) On subsequent oracle reports, CoverageFund is pulled → `BalanceToDeposit` increases → `_assetBalance()` recovers → conversion rate recovers. The recovery is rate-limited by `availableAmountToUpperBound` (same as slashing recovery). |

## Concrete Mechanism

### 1. Failure detection: Oracle-reported + timeout

Two complementary detection paths:

**Path A: Oracle detects explicitly**
```
Oracle monitors pending consolidations:
  - Source validator exited (withdrawable_epoch reached, balance swept)
  - No corresponding increase in validatorsConsolidatedBalance for the target
  - Oracle includes failed consolidation data in report:
    failedConsolidationIds[] in ConsensusLayerReport
```

**Path B: Timeout-based**
```
Each ConsolidationRequest has a requestTimestamp (set at executeConsolidation).
If currentTimestamp > requestTimestamp + MAX_CONSOLIDATION_DURATION:
  - Consolidation considered failed
  - Admin or oracle can trigger writedown
```

`MAX_CONSOLIDATION_DURATION` should be generous (e.g., 7 days) to account for CL delays, but bounded to limit insolvency window.

### 2. Buffer writedown

```solidity
// Called by oracle (via report) or admin
function writeDownFailedConsolidation(uint256 _requestId) external {
    // Only oracle or admin
    ConsolidationRequest storage request = consolidationRequests[_requestId];
    require(request.status == PENDING);

    // Write down the buffer
    uint256 failedAmount = request.expectedBalance - request.reconciledBalance;
    PendingConsolidationBalance -= failedAmount;

    request.status = FAILED;

    emit ConsolidationFailed(_requestId, failedAmount);
}
```

**Impact on `_assetBalance()`:**
- Before writedown: `_assetBalance()` includes the phantom `failedAmount` → conversion rate inflated
- After writedown: `_assetBalance()` drops by `failedAmount` → conversion rate drops
- Loss is immediately socialized across all LsETH holders

### 3. Recovery via CoverageFund

```
Timeline:
  T=0:   Consolidation executed, LsETH minted, PendingConsolidationBalance += X
  T+27h: Expected completion. Balance doesn't arrive.
  T+7d:  Timeout triggers. Admin/oracle writes down PendingConsolidationBalance -= X.
         _assetBalance() drops by X. Conversion rate drops. Loss socialized.
  T+?:   Alluvial/insurance donates X ETH to CoverageFund.
         Next oracle reports gradually pull CoverageFund → BalanceToDeposit.
         _assetBalance() recovers. Conversion rate recovers.
```

**No new mechanism needed** — the existing CoverageFund donation + pull flow handles recovery. The only new pieces are:
1. Detection logic (oracle reporting failed consolidations or timeout)
2. Writedown function on River

### 4. Impact analysis

For a failed consolidation of amount X, with total `_assetBalance()` of T:

```
Conversion rate impact = X / T

Example: 100 ETH failed consolidation, 100,000 ETH total assets
  → 0.1% conversion rate drop
  → Each LsETH holder loses 0.1% value temporarily
  → Recovered when CoverageFund is replenished
```

### 5. Risk mitigation (reduce probability of failure)

The insolvency protection is a backstop. The primary defense is **preventing failures**:

| Mitigation | Mechanism |
|------------|-----------|
| **Keeper validates CL state** | Keeper checks source validator is eligible for consolidation before calling `executeConsolidation()`. Checks: active status, not slashed, not exiting, sufficient balance. |
| **Oracle confirms CL acceptance** | Before minting could be deferred to oracle confirmation (A3-C). Rejected for UX reasons, but remains an option for high-value consolidations. |
| **Consolidation amount cap** | Admin-configurable maximum single consolidation amount. Limits exposure per consolidation. |
| **Total pending cap** | Admin-configurable maximum total `PendingConsolidationBalance`. Limits total protocol exposure. |
| **Allowlist vetting** | Only allowlisted institutional validators can consolidate. Reduces risk of malicious or unreliable source validators. |

### 6. Oracle report extension for failure detection

```solidity
struct ConsensusLayerReport {
    // ... existing fields ...
    uint256 validatorsConsolidatedBalance;     // from buffer reconciliation spike

    // NEW: failed consolidation reporting
    uint32[] failedConsolidationIds;           // request IDs of consolidations that failed on CL
}
```

In `setConsensusLayerData`:
```
// After reconciling successful consolidations...
for each failedId in report.failedConsolidationIds:
    writeDownFailedConsolidation(failedId)
```

## Edge Cases

| Case | What happens |
|------|--------------|
| **Partial failure** (some ETH arrives, not all) | `validatorsConsolidatedBalance` delta < expected. Remaining amount stays in buffer. Eventually detected as partial failure if no further reconciliation. Writedown only for the unreconciled portion. |
| **CoverageFund is empty** | Loss remains socialized until fund is replenished. Conversion rate stays depressed. This is the same as current slashing behavior — there's no instant guarantee. |
| **Multiple simultaneous failures** | Each writedown is independent. Total impact = sum of failed amounts. Cumulative cap on `PendingConsolidationBalance` limits maximum exposure. |
| **False positive timeout** (consolidation is just slow) | Use a generous timeout (7+ days). If consolidation completes after writedown, the `validatorsConsolidatedBalance` delta will arrive as unexpected income — treated as a gain, gradually absorbed. Admin can also manually adjust. |
| **Consolidation fails before CL acceptance** | If the CL rejects the request entirely, the source validator never exits. Oracle detects no change. Timeout triggers writedown. |

## Conclusion

Insolvency protection for failed consolidations requires two new pieces:
1. **Detection:** Oracle reports `failedConsolidationIds[]` + timeout-based fallback
2. **Writedown:** `PendingConsolidationBalance -= failedAmount`, loss socialized to all holders

Recovery uses the **existing CoverageFund mechanism** unchanged — donate ETH, oracle pulls it gradually, `_assetBalance()` recovers.

Primary defense is **prevention** (keeper CL validation, amount caps, allowlist vetting), with CoverageFund as the backstop. This is architecturally consistent with how slashing losses are already handled.
