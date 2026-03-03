---
shaping: true
---

# Buffer Reconciliation Spike

## Context

Shape A proposes a `PendingConsolidationBalance` buffer to track ETH "in transit" from consolidations. This buffer must be reconciled against the oracle's aggregate CL balance so that:
- Consolidated ETH isn't double-counted in `_assetBalance()`
- Consolidated ETH isn't mistaken for rewards (which would trigger fee minting)
- The `annualAprUpperBound` check isn't tripped by large consolidation-driven balance increases

## Goal

Understand the exact mechanics of how `PendingConsolidationBalance` integrates into the existing oracle reporting flow (`setConsensusLayerData`) and `_assetBalance()`.

## Questions

| # | Question | Answer |
|---|----------|--------|
| **Q1** | How does the oracle currently distinguish between different sources of `validatorsBalance` change (rewards, skimming, exits)? | It doesn't distinguish within `validatorsBalance` itself. Instead it uses **separate cumulative fields**: `validatorsSkimmedBalance` (cumulative, non-decreasing) and `validatorsExitedBalance` (cumulative, non-decreasing). The delta between reports gives the new skimmed/exited amounts. `validatorsBalance` is the live CL balance (can decrease). Rewards are derived implicitly: `_assetBalance()` delta after applying all report values = rewards. |
| **Q2** | What happens to `_assetBalance()` when a consolidation completes on CL (i.e., balance transfers from source to target LC validator)? | **Without a buffer:** `validatorsBalance` jumps by the consolidated amount → `_assetBalance()` jumps → treated as rewards → fee shares minted on non-reward ETH → conversion rate distorted. Also likely trips `annualAprUpperBound`. **This is the core problem.** |
| **Q3** | How can the oracle report consolidation transfers so River can reconcile the buffer? | **Same pattern as skimmed/exited:** Add a new cumulative field `validatorsConsolidatedBalance` to `ConsensusLayerReport`. The oracle tracks all ETH transferred into LC validators via consolidation. Delta between reports = new consolidation transfers. This is the cleanest approach — consistent with existing patterns. |
| **Q4** | Where in the `setConsensusLayerData` flow should reconciliation happen? | Between `_pullCLFunds` (step 2) and the `_assetBalance()` post-report read (step 4). Specifically: after updating `LastConsensusLayerReport` (which updates `validatorsBalance`), reduce `PendingConsolidationBalance` by the consolidation delta. Then when `postReportUnderlyingBalance = _assetBalance()` runs, the consolidation portion cancels out (higher `validatorsBalance` offset by lower `PendingConsolidationBalance`), leaving only real rewards in the delta. |
| **Q5** | Does this work with multiple in-flight consolidations? | Yes. `PendingConsolidationBalance` is a **sum** of all pending consolidations. `validatorsConsolidatedBalance` is **cumulative** across all consolidations. Each report reconciles whatever portion of pending consolidations has completed, regardless of count or order. |
| **Q6** | What about the bounds checking? Does the buffer prevent false `TotalValidatorBalanceIncreaseOutOfBound` reverts? | Yes. The math: `preReport = validatorsBalance(old) + ... + PendingConsolidation(old)`. `postReport = validatorsBalance(new, includes consolidated) + ... + PendingConsolidation(old) - consolidatedDelta`. The consolidation amount cancels: `+consolidated in validatorsBalance` and `-consolidatedDelta from buffer`. Only rewards remain in `postReport - preReport`. Bounds check passes. |
| **Q7** | When is `PendingConsolidationBalance` incremented — at initiation or at CL acceptance? | **At CL acceptance** (when oracle confirms source validator's exit_epoch is set). This is when the protocol is certain the consolidation is proceeding. Adding to buffer at initiation would risk inflating `_assetBalance()` for consolidations that get rejected on CL. |

## Concrete Mechanism

### 1. New oracle report field

```solidity
struct ConsensusLayerReport {
    // ... existing fields ...

    // NEW: cumulative sum of all ETH consolidated into LC validators
    // follows same pattern as validatorsSkimmedBalance / validatorsExitedBalance
    // non-decreasing across reports
    uint256 validatorsConsolidatedBalance;
}
```

### 2. New storage variable

```solidity
// PendingConsolidationBalance — total ETH expected from in-flight consolidations
// Incremented when oracle confirms CL acceptance (source exit_epoch set)
// Decremented when oracle reports consolidation transfer complete
```

### 3. Modified `_assetBalance()`

```solidity
function _assetBalance() internal view returns (uint256) {
    // ... existing logic ...
    return storedReport.validatorsBalance
        + BalanceToDeposit.get()
        + CommittedBalance.get()
        + BalanceToRedeem.get()
        + PendingConsolidationBalance.get()   // ← NEW
        + inFlightValidatorBalance;            // (depositedCount - clCount) * 32 ETH
}
```

### 4. Modified `setConsensusLayerData` flow

```
Step 1: preReportUnderlyingBalance = _assetBalance()
           → includes PendingConsolidationBalance(old)

Step 2: Pull CL funds (skimmed + exited) — unchanged

Step 3: Compute consolidation delta:
           consolidatedIncrease = report.validatorsConsolidatedBalance
                                - lastReport.validatorsConsolidatedBalance
           PendingConsolidationBalance -= consolidatedIncrease

Step 4: Update LastConsensusLayerReport (new validatorsBalance, etc.)

Step 5: postReportUnderlyingBalance = _assetBalance()
           → validatorsBalance now includes consolidated ETH
           → PendingConsolidationBalance is reduced by same amount
           → NET DELTA = rewards only (consolidation cancels out)

Step 6: Bounds check, fee minting, etc. — unchanged, works correctly
```

### 5. Consolidation lifecycle

```
Initiation (EL tx)          → consolidation request recorded, NO buffer change yet
CL Acceptance (oracle)      → PendingConsolidationBalance += expectedBalance
                               LsETH minted to consolidator
Balance Transfer (oracle)   → validatorsConsolidatedBalance increases
                               PendingConsolidationBalance -= transferredAmount
                               (net _assetBalance() change = 0)
```

## Edge Cases

| Case | What happens |
|------|--------------|
| **Consolidation fails after CL acceptance** | PendingConsolidationBalance remains inflated. Oracle reports no increase in `validatorsConsolidatedBalance`. Need a timeout/admin mechanism to write down the buffer → triggers insolvency protection (R6). |
| **Partial consolidation** (less ETH arrives than expected) | `validatorsConsolidatedBalance` delta < expected. Buffer remains partially inflated. Same writedown mechanism needed. |
| **Consolidation completes across report boundaries** | Works naturally — cumulative `validatorsConsolidatedBalance` captures the transfer whenever it happens. Buffer reconciles in the report where transfer completes. |
| **Multiple consolidations in same report window** | All captured in single `validatorsConsolidatedBalance` delta. Buffer decrements by total. |
| **Oracle reports consolidation but no matching pending** (rogue) | `consolidatedIncrease > PendingConsolidationBalance` → underflow. Need a guard: `min(consolidatedIncrease, PendingConsolidationBalance)`. Excess is unmatched consolidated ETH — effectively a gift to the protocol (increases `_assetBalance()` → treated as rewards). |

## Conclusion

The buffer reconciliation follows the **exact same pattern** as the existing skimmed/exited balance tracking:
- Cumulative, non-decreasing oracle field
- Delta computed between reports
- River adjusts internal state based on delta

The key insight is that `PendingConsolidationBalance` in `_assetBalance()` pre-accounts for incoming ETH (so LsETH can be minted immediately at correct conversion rate), and the oracle's `validatorsConsolidatedBalance` delta reconciles it (so it's not double-counted once ETH arrives on CL).
