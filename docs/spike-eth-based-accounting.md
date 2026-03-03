---
shaping: true
---

# A9 Spike: ETH-Based Accounting (Remove 32 ETH / Count Dependencies)

## Context

The protocol currently uses `DEPOSIT_SIZE (32 ETH)` and validator counts in three accounting calculations:
1. In-flight deposit balance in `_assetBalance()`
2. Pre-exiting balance in exit demand calculation
3. Exit demand quantity (validators to exit)

Post-Pectra, validators can have >32 ETH (via consolidation). These count-based calculations become incorrect. We need to replace them with direct ETH amount tracking.

## Goal

Determine the concrete replacement mechanism for each of the three 32 ETH / count dependencies, ensuring `_assetBalance()` and exit demand calculations use actual ETH amounts.

## Questions

| # | Question | Answer |
|---|----------|--------|
| **Q1** | What does the in-flight calculation `(depositedCount - clCount) * 32 ETH` represent? | ETH that has left River (sent to beacon deposit contract) but isn't yet reflected in the oracle's `validatorsBalance`. Between deposit and validator activation on CL, there's a gap. Without this term, `_assetBalance()` would drop by 32 ETH per deposit and recover when the oracle reports the new validator — causing conversion rate fluctuations. |
| **Q2** | How do we track in-flight ETH without using counts? | New `InFlightDepositBalance` storage variable. **Incremented** by 32 ETH each time `_depositValidator()` is called in `ConsensusLayerDepositManager`. **Decremented** when the oracle reports new validators. Currently the oracle reports `validatorsCount` increases. When count goes up by N, `InFlightDepositBalance -= N * 32 ETH`. This still uses 32 ETH per new validator, but that's correct — each new deposit IS 32 ETH. The key difference: in-flight balance is tracked as an ETH variable, not derived from count arithmetic. |
| **Q3** | Wait — if new deposits are always 32 ETH, isn't `InFlightDepositBalance` always `(deposited - cl) * 32`? | Yes, for new deposits it's mathematically equivalent. But the **decrement** side is where it matters. Currently it relies on `clValidatorCount` matching `depositedValidatorCount` over time. With consolidation, `validatorsCount` may not increase the same way (a consolidation doesn't create a new validator, it merges into an existing one). By tracking the actual ETH amount, we decouple from count semantics entirely. Also, if future deposit sizes change, the variable still works. |
| **Q4** | How does `preExitingBalance` work without `(requested - stopped) * 32`? | Currently `preExitingBalance` estimates how much ETH is "on the way" from exit requests that haven't completed yet. Replace with: `PendingFullExitBalance` — a storage variable tracking ETH expected from pending full exits. **Incremented** when keeper requests full exits — keeper provides the actual validator balance for each exit (from CL data). **Decremented** when oracle reports the exited balance via `validatorsExitedBalance`. Combined with `PendingPartialExitBalance` (from V2): `preExitingBalance = PendingFullExitBalance + PendingPartialExitBalance`. |
| **Q5** | How does exit demand change from count-based to ETH-based? | Currently: `demandValidatorExits(validatorCount, depositedCount)` on OperatorsRegistry — tracks demand as a count. Replace with: `demandExitBalance(ethAmount)` — tracks demand as ETH. New `CurrentExitDemandBalance` replaces `CurrentValidatorExitsDemand`. The keeper then fills this demand using a mix of partial exits (specific ETH amounts) and full exits (actual validator balances from CL). The on-chain math works in ETH throughout — no count-based assumptions. |
| **Q6** | How does the keeper know validator balances for full exits? | The keeper already has CL visibility (for BYOV deposit allocation). When requesting full exits, the keeper provides the actual balance per validator. This is already how the keeper works for partial exits (A6/A7). For full exits: keeper calls `requestExits()` with `FullExitRequest{pubkey, expectedBalance}` where `expectedBalance` comes from CL data. |
| **Q7** | Does `validatorsCount` in the oracle report still serve a purpose? | Yes, but only for **CL validation**, not accounting. The oracle still reports validator count for sanity checks (e.g., can't exceed deposited count, can't decrease). But it's no longer used in `_assetBalance()` or exit demand calculations. |

## Concrete Changes

### 1. InFlightDepositBalance — replaces `(depositedCount - clCount) * 32`

**Storage:** `contracts/src/state/river/InFlightDepositBalance.sol`

**Increment** in `ConsensusLayerDepositManager._depositValidator()`:
```solidity
// After each successful deposit to beacon chain
InFlightDepositBalance.set(InFlightDepositBalance.get() + DEPOSIT_SIZE);
```

**Decrement** in `OracleManager.setConsensusLayerData()`:
```solidity
// When oracle reports new validators activated
uint32 newValidators = _report.validatorsCount - lastStoredReport.validatorsCount;
if (newValidators > 0) {
    uint256 activatedBalance = uint256(newValidators) * _DEPOSIT_SIZE;
    uint256 current = InFlightDepositBalance.get();
    // Guard against underflow (shouldn't happen, but defensive)
    InFlightDepositBalance.set(current > activatedBalance ? current - activatedBalance : 0);
}
```

**Modified `_assetBalance()`:**
```solidity
function _assetBalance() internal view override returns (uint256) {
    IOracleManagerV1.StoredConsensusLayerReport storage storedReport = LastConsensusLayerReport.get();
    return storedReport.validatorsBalance
        + BalanceToDeposit.get()
        + CommittedBalance.get()
        + BalanceToRedeem.get()
        + PendingConsolidationBalance.get()
        + InFlightDepositBalance.get();     // replaces (depositedCount - clCount) * 32
}
```

**Note:** `DepositedValidatorCount` and `CLValidatorCount` (from oracle) are still maintained for CL validation and event reporting, but no longer used in `_assetBalance()`.

### 2. PendingFullExitBalance — replaces `(requested - stopped) * 32`

**Storage:** `contracts/src/state/river/PendingFullExitBalance.sol`

**Increment** in `River.requestExits()` — when keeper requests full exits:
```solidity
struct FullExitRequest {
    bytes pubkey;
    uint256 expectedBalance;  // actual CL balance, provided by keeper
}

struct ExitRequest {
    PartialExitRequest[] partialExits;
    FullExitRequest[] fullExits;  // CHANGED from OperatorAllocation[]
}

// In requestExits():
for each fullExit in _request.fullExits:
    PendingFullExitBalance += fullExit.expectedBalance;
    // Also route to OperatorsRegistry for operator accounting
```

**Decrement** in oracle report — when exited funds arrive:
```solidity
// exitedAmountIncrease includes both full and partial exits
// Partial exits are reconciled via PendingPartialExitBalance
// Full exits are reconciled via PendingFullExitBalance
// We need to distinguish them — use validatorsPartiallyExitedBalance delta for partial
// Remainder of exitedAmountIncrease = full exit funds

uint256 fullExitReconcile = exitedAmountIncrease - partialExitIncrease;
PendingFullExitBalance -= min(fullExitReconcile, PendingFullExitBalance);
```

**Modified preExitingBalance:**
```solidity
// OLD: (requestedExits - stopped) * DEPOSIT_SIZE
// NEW:
uint256 preExitingBalance = PendingFullExitBalance.get() + PendingPartialExitBalance.get();
```

### 3. ETH-based exit demand — replaces count-based demand

**OperatorsRegistry changes:**

Replace:
- `CurrentValidatorExitsDemand` (count) → `CurrentExitDemandBalance` (ETH)
- `demandValidatorExits(count, depositedCount)` → `demandExitBalance(ethAmount)`

```solidity
function demandExitBalance(uint256 _ethAmount) external onlyRiver {
    CurrentExitDemandBalance.set(CurrentExitDemandBalance.get() + _ethAmount);
    emit SetCurrentExitDemandBalance(CurrentExitDemandBalance.get());
}
```

**River exit demand calculation:**
```solidity
// OLD:
// validatorCountToExit = ceil(shortfall / DEPOSIT_SIZE);
// or.demandValidatorExits(validatorCountToExit, DepositedValidatorCount.get());

// NEW:
uint256 preExitingBalance = PendingFullExitBalance.get() + PendingPartialExitBalance.get();
if (availableBalanceToRedeem + _exitingBalance + preExitingBalance < redeemManagerDemandInEth) {
    uint256 exitDemand = redeemManagerDemandInEth
        - (availableBalanceToRedeem + _exitingBalance + preExitingBalance);
    or.demandExitBalance(exitDemand);
}
```

**Keeper fills the demand:**
```solidity
// Keeper reads CurrentExitDemandBalance
// Decides mix of partial + full exits based on CL state
// Calls River.requestExits() with actual amounts
// CurrentExitDemandBalance decremented by filled amount
```

### 4. Summary of where DEPOSIT_SIZE is still used (deposit mechanics only)

| Location | Use | Why it stays |
|----------|-----|-------------|
| `_commitBalanceToDeposit` rounding | `amount / DEPOSIT_SIZE * DEPOSIT_SIZE` | Deposits must be exact multiples of 32 ETH |
| `depositToConsensusLayer` | `committedBalance / DEPOSIT_SIZE` | Each CL deposit is exactly 32 ETH |
| `_depositValidator` | `value = DEPOSIT_SIZE` | Beacon deposit contract requires 32 ETH |
| `InFlightDepositBalance` increment | `+= DEPOSIT_SIZE` | Each deposit adds exactly 32 ETH to in-flight |
| Oracle: new validator activation | `newCount * DEPOSIT_SIZE` for decrementing InFlightDepositBalance | Each activated validator was deposited at 32 ETH |

These are all **deposit mechanics** — the physical act of depositing is 32 ETH. This is a protocol/beacon chain constraint, not an accounting assumption.

## Migration

On upgrade (`initRiverV1_3`):
```solidity
// Initialize InFlightDepositBalance from current state
uint256 depositedCount = DepositedValidatorCount.get();
uint256 clCount = LastConsensusLayerReport.get().validatorsCount;
if (depositedCount > clCount) {
    InFlightDepositBalance.set((depositedCount - clCount) * 32 ether);
}

// Initialize PendingFullExitBalance = 0 (no pending exits at upgrade time)
// Initialize CurrentExitDemandBalance from CurrentValidatorExitsDemand
uint256 currentDemand = CurrentValidatorExitsDemand.get();
CurrentExitDemandBalance.set(currentDemand * 32 ether); // conservative estimate
```

## Conclusion

Three replacements, all following the same principle — **track ETH amounts directly instead of deriving from counts**:

| Old (count-based) | New (ETH-based) |
|---|---|
| `(depositedCount - clCount) * 32` | `InFlightDepositBalance` |
| `(requestedExits - stopped) * 32` | `PendingFullExitBalance + PendingPartialExitBalance` |
| `ceil(shortfall / 32)` validators → `demandValidatorExits(count)` | `shortfall` ETH → `demandExitBalance(ethAmount)` |

`DEPOSIT_SIZE` and validator counts remain for deposit mechanics and CL validation only — never for balance accounting.
