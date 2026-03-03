---
shaping: true
---

# V0 Plan: ETH-Based Accounting Foundation

**Parts:** A9
**Demo:** `_assetBalance()` uses `InFlightDepositBalance` instead of `(depositedCount - clCount) * 32`. Exit demand and pre-exiting balance track ETH amounts. No balance accounting depends on `DEPOSIT_SIZE` or validator counts.
**Prerequisite for:** V1, V2

---

## Design Principle

**System-level balance accounting → ETH-based.** River tracks ETH amounts for `_assetBalance()`, exit demand, and pre-exiting balance.

**Operator-level management → count-based (unchanged).** OperatorsRegistry keeps `operator.funded`, `operator.requestedExits`, `stoppedValidatorCounts` as counts. These are operational (which operator has how many validators) not balance accounting.

**Bridge:** The keeper provides both operator allocations (counts, for operator tracking) and ETH amounts (for system accounting) when requesting exits.

---

## Step-by-step Implementation

### Step 1: New state storage files

**File: `contracts/src/state/river/InFlightDepositBalance.sol`**
```solidity
library InFlightDepositBalance {
    bytes32 internal constant IN_FLIGHT_DEPOSIT_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.inFlightDepositBalance")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(IN_FLIGHT_DEPOSIT_BALANCE_SLOT);
    }

    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(IN_FLIGHT_DEPOSIT_BALANCE_SLOT, _newValue);
    }
}
```

**File: `contracts/src/state/river/PendingFullExitBalance.sol`**
```solidity
library PendingFullExitBalance {
    bytes32 internal constant PENDING_FULL_EXIT_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.pendingFullExitBalance")) - 1);

    function get() internal view returns (uint256) { ... }
    function set(uint256 _newValue) internal { ... }
}
```

**File: `contracts/src/state/operatorsRegistry/CurrentExitDemandBalance.sol`**
```solidity
library CurrentExitDemandBalance {
    bytes32 internal constant CURRENT_EXIT_DEMAND_BALANCE_SLOT =
        bytes32(uint256(keccak256("operatorsRegistry.state.currentExitDemandBalance")) - 1);

    function get() internal view returns (uint256) { ... }
    function set(uint256 _newValue) internal { ... }
}
```

### Step 2: ConsensusLayerDepositManager — track deposits as ETH

**File: `contracts/src/components/ConsensusLayerDepositManager.1.sol`**

Add new virtual function for tracking in-flight balance:

```solidity
/// @notice Handler called to increase the in-flight deposit balance
/// @param _amount The amount deposited
function _increaseInFlightDepositBalance(uint256 _amount) internal virtual;
```

In `depositToConsensusLayerWithDepositRoot()`, after the deposit loop (line ~147):

```solidity
// EXISTING:
_setCommittedBalance(committedBalance - DEPOSIT_SIZE * receivedPublicKeyCount);
uint256 currentDepositedValidatorCount = DepositedValidatorCount.get();
DepositedValidatorCount.set(currentDepositedValidatorCount + receivedPublicKeyCount);

// NEW: Track ETH in flight
_increaseInFlightDepositBalance(DEPOSIT_SIZE * receivedPublicKeyCount);
```

Implemented in River.1.sol:
```solidity
function _increaseInFlightDepositBalance(uint256 _amount) internal override {
    uint256 current = InFlightDepositBalance.get();
    InFlightDepositBalance.set(current + _amount);
    emit SetInFlightDepositBalance(current, current + _amount);
}
```

**Note:** `DepositedValidatorCount` is still maintained (for CL validation in oracle reports, operator accounting) but no longer used in `_assetBalance()`.

### Step 3: OracleManager — decrement InFlightDepositBalance on validator activation

**File: `contracts/src/components/OracleManager.1.sol`**

New virtual function:
```solidity
/// @notice Handler called to decrease the in-flight deposit balance when validators activate
/// @param _newValidatorCount The number of newly activated validators
function _decreaseInFlightDepositBalance(uint32 _newValidatorCount) internal virtual;
```

In `setConsensusLayerData()`, after storing the new report (where `validatorsCount` is updated):

```solidity
{
    uint32 lastCount = lastStoredReport.validatorsCount;
    uint32 newCount = _report.validatorsCount;
    if (newCount > lastCount) {
        _decreaseInFlightDepositBalance(newCount - lastCount);
    }
}
```

Implemented in River.1.sol:
```solidity
function _decreaseInFlightDepositBalance(uint32 _newValidatorCount) internal override {
    uint256 activatedBalance = uint256(_newValidatorCount) * DEPOSIT_SIZE;
    uint256 current = InFlightDepositBalance.get();
    uint256 newValue = current > activatedBalance ? current - activatedBalance : 0;
    InFlightDepositBalance.set(newValue);
    emit SetInFlightDepositBalance(current, newValue);
}
```

**Why `* DEPOSIT_SIZE` is still correct here:** Each new validator was deposited at exactly 32 ETH. This is a deposit mechanical fact (beacon deposit contract requires 32 ETH), not a balance accounting assumption. We're converting a count delta into the ETH delta it represents.

### Step 4: River — modified _assetBalance()

**File: `contracts/src/River.1.sol`** (line ~392)

```solidity
// OLD:
function _assetBalance() internal view override returns (uint256) {
    IOracleManagerV1.StoredConsensusLayerReport storage storedReport = LastConsensusLayerReport.get();
    uint256 clValidatorCount = storedReport.validatorsCount;
    uint256 depositedValidatorCount = DepositedValidatorCount.get();
    if (clValidatorCount < depositedValidatorCount) {
        return storedReport.validatorsBalance + BalanceToDeposit.get() + CommittedBalance.get()
            + BalanceToRedeem.get() + (depositedValidatorCount - clValidatorCount)
            * ConsensusLayerDepositManagerV1.DEPOSIT_SIZE;
    } else {
        return
            storedReport.validatorsBalance + BalanceToDeposit.get() + CommittedBalance.get() + BalanceToRedeem.get();
    }
}

// NEW:
function _assetBalance() internal view override returns (uint256) {
    IOracleManagerV1.StoredConsensusLayerReport storage storedReport = LastConsensusLayerReport.get();
    return storedReport.validatorsBalance
        + BalanceToDeposit.get()
        + CommittedBalance.get()
        + BalanceToRedeem.get()
        + InFlightDepositBalance.get();
}
```

No branching. No count arithmetic. Direct ETH amount.

### Step 5: OperatorsRegistry — ETH-based exit demand

**File: `contracts/src/OperatorsRegistry.1.sol`**

New function alongside existing `demandValidatorExits`:

```solidity
/// @notice Demands exit balance from the system (ETH-based)
/// @param _ethAmount The amount of ETH needed from exits
function demandExitBalance(uint256 _ethAmount) external onlyRiver {
    uint256 currentDemand = CurrentExitDemandBalance.get();
    CurrentExitDemandBalance.set(currentDemand + _ethAmount);
    emit SetCurrentExitDemandBalance(currentDemand, currentDemand + _ethAmount);
}

/// @notice Get the current exit demand in ETH
function getCurrentExitDemandBalance() external view returns (uint256) {
    return CurrentExitDemandBalance.get();
}
```

### Step 6: River — ETH-based exit demand calculation

**File: `contracts/src/River.1.sol`** — `_requestExitsBasedOnRedeemDemandAfterRebalancings()`

```solidity
// OLD (lines 545-562):
// (uint256 totalStoppedValidatorCount, uint256 totalRequestedExitsCount) =
//     or.getStoppedAndRequestedExitCounts();
// uint256 preExitingBalance =
//     (totalRequestedExitsCount > totalStoppedValidatorCount
//         ? (totalRequestedExitsCount - totalStoppedValidatorCount) : 0) * DEPOSIT_SIZE;
// if (availableBalanceToRedeem + _exitingBalance + preExitingBalance < redeemManagerDemandInEth) {
//     uint256 validatorCountToExit = LibUint256.ceil(
//         redeemManagerDemandInEth - (availableBalanceToRedeem + _exitingBalance + preExitingBalance),
//         DEPOSIT_SIZE
//     );
//     or.demandValidatorExits(validatorCountToExit, DepositedValidatorCount.get());
// }

// NEW:
uint256 preExitingBalance = PendingFullExitBalance.get(); // + PendingPartialExitBalance (added in V2)

if (availableBalanceToRedeem + _exitingBalance + preExitingBalance < redeemManagerDemandInEth) {
    uint256 exitDemand = redeemManagerDemandInEth
        - (availableBalanceToRedeem + _exitingBalance + preExitingBalance);

    IOperatorsRegistryV1(OperatorsRegistryAddress.get()).demandExitBalance(exitDemand);
}
```

### Step 7: Keeper exit request — bridge ETH amounts to operator counts

**File: `contracts/src/River.1.sol`**

The keeper must provide both ETH amounts (for system accounting) and operator allocations (for operator tracking). New struct and function:

```solidity
struct FullExitRequest {
    uint256 operatorIndex;
    bytes pubkey;              // 48 bytes
    uint256 expectedBalance;   // actual CL balance from keeper
}

/// @notice Keeper requests full validator exits with ETH amounts
/// @param _exits The full exit requests with actual validator balances
function requestFullExits(FullExitRequest[] calldata _exits) external {
    if (msg.sender != KeeperAddress.get()) {
        revert OnlyKeeper();
    }

    uint256 totalExitBalance = 0;

    // Build operator allocations for OperatorsRegistry (count-based, for operator tracking)
    // And accumulate ETH amounts for system accounting
    for (uint256 i = 0; i < _exits.length; ++i) {
        totalExitBalance += _exits[i].expectedBalance;
    }

    // Update system-level ETH tracking
    PendingFullExitBalance.set(PendingFullExitBalance.get() + totalExitBalance);

    // Decrement ETH demand
    uint256 currentDemand = IOperatorsRegistryV1(OperatorsRegistryAddress.get())
        .getCurrentExitDemandBalance();
    uint256 filledDemand = LibUint256.min(totalExitBalance, currentDemand);
    if (filledDemand > 0) {
        IOperatorsRegistryV1(OperatorsRegistryAddress.get())
            .fillExitDemandBalance(filledDemand);
    }

    // Route to OperatorsRegistry for operator-level count tracking
    // (aggregate by operator, build OperatorAllocation[])
    _routeFullExitsToOperatorRegistry(_exits);

    emit FullExitsRequested(totalExitBalance, _exits.length);
}
```

New function on OperatorsRegistry:
```solidity
/// @notice Fills exit demand balance (ETH-based), called by River
/// @param _ethAmount The amount of ETH being filled
function fillExitDemandBalance(uint256 _ethAmount) external onlyRiver {
    uint256 currentDemand = CurrentExitDemandBalance.get();
    uint256 filled = LibUint256.min(_ethAmount, currentDemand);
    CurrentExitDemandBalance.set(currentDemand - filled);
    emit SetCurrentExitDemandBalance(currentDemand, currentDemand - filled);
}
```

### Step 8: Oracle — reconcile PendingFullExitBalance

**File: `contracts/src/components/OracleManager.1.sol`**

When the oracle reports `validatorsExitedBalance` increase, some of that is from full exits. In `setConsensusLayerData()`:

```solidity
// exitedAmountIncrease already computed (existing code)
// In V2, partialExitIncrease will be subtracted. For V0, all exited = full exits.
if (exitedAmountIncrease > 0) {
    _reconcileFullExits(exitedAmountIncrease);
}
```

New virtual function:
```solidity
function _reconcileFullExits(uint256 _exitedIncrease) internal virtual;
```

Implemented in River.1.sol:
```solidity
function _reconcileFullExits(uint256 _exitedIncrease) internal override {
    uint256 currentPending = PendingFullExitBalance.get();
    uint256 reconcileAmount = LibUint256.min(_exitedIncrease, currentPending);
    if (reconcileAmount > 0) {
        PendingFullExitBalance.set(currentPending - reconcileAmount);
        emit FullExitsReconciled(_exitedIncrease, reconcileAmount);
    }
}
```

**Note:** In V2, partial exit reconciliation happens first (`_exitedIncrease -= partialExitDelta`), then the remainder reconciles `PendingFullExitBalance`.

### Step 9: Unsolicited exits — handle in ETH terms

**File: `contracts/src/OperatorsRegistry.1.sol`** — `_setStoppedValidatorCounts()`

Currently, unsolicited exits (operators exiting without being asked) decrement `CurrentValidatorExitsDemand` (count-based). We need to also decrement `CurrentExitDemandBalance`.

In the unsolicited exit handling (lines 644-650, 667-673):

```solidity
// EXISTING (keep for operator tracking):
if (_stoppedValidatorCounts[idx] > operators[idx - 1].requestedExits) {
    unsolicitedExitsSum += _stoppedValidatorCounts[idx] - operators[idx - 1].requestedExits;
    operators[idx - 1].requestedExits = _stoppedValidatorCounts[idx];
}

// EXISTING (keep):
vars.currentValidatorExitsDemand -= LibUint256.min(unsolicitedExitsSum, vars.currentValidatorExitsDemand);

// NEW: Also decrement ETH-based demand (conservative estimate: count * 32 ETH)
// This is a rough estimate since we don't know actual validator balances here.
// The real reconciliation happens when exited funds arrive via oracle report.
uint256 unsolicitedExitBalanceEstimate = unsolicitedExitsSum * 32 ether;
uint256 currentEthDemand = CurrentExitDemandBalance.get();
CurrentExitDemandBalance.set(
    currentEthDemand > unsolicitedExitBalanceEstimate
        ? currentEthDemand - unsolicitedExitBalanceEstimate
        : 0
);
```

**Note:** Using `32 ether` as estimate for unsolicited exits is acceptable here because:
1. It's a demand reduction (conservative is fine — might under-reduce, but keeper will fill the rest)
2. The actual ETH reconciliation happens via `PendingFullExitBalance` when oracle reports exited funds
3. Post-V2, unsolicited exits of >32 ETH validators will be more accurately handled as the keeper provides actual balances

### Step 10: Interface updates

**File: `contracts/src/interfaces/IRiver.1.sol`**

Add:
- `FullExitRequest` struct
- `requestFullExits(FullExitRequest[])` signature
- `getInFlightDepositBalance()` view
- `getPendingFullExitBalance()` view
- Events: `SetInFlightDepositBalance`, `FullExitsRequested`, `FullExitsReconciled`

**File: `contracts/src/interfaces/IOperatorRegistry.1.sol`**

Add:
- `demandExitBalance(uint256)` signature
- `fillExitDemandBalance(uint256)` signature
- `getCurrentExitDemandBalance()` view
- Event: `SetCurrentExitDemandBalance`

### Step 11: Migration (initRiverV1_3)

**File: `contracts/src/River.1.sol`**

```solidity
function initRiverV1_3() external init(3) {
    // Initialize InFlightDepositBalance from current state
    uint256 depositedCount = DepositedValidatorCount.get();
    uint256 clCount = LastConsensusLayerReport.get().validatorsCount;
    if (depositedCount > clCount) {
        uint256 inFlight = (depositedCount - clCount) * DEPOSIT_SIZE;
        InFlightDepositBalance.set(inFlight);
        emit SetInFlightDepositBalance(0, inFlight);
    }

    // PendingFullExitBalance starts at 0 (no pending exits tracked in ETH yet)
    // Any existing pre-exiting validators will be reconciled as their exits complete
}
```

**File: `contracts/src/OperatorsRegistry.1.sol`**

```solidity
function initOperatorsRegistryV1_3() external init(X) {
    // Initialize CurrentExitDemandBalance from count-based demand
    uint256 countDemand = CurrentValidatorExitsDemand.get();
    uint256 ethDemand = countDemand * 32 ether; // conservative estimate
    CurrentExitDemandBalance.set(ethDemand);
    emit SetCurrentExitDemandBalance(0, ethDemand);
}
```

### Step 12: Tests

1. **Unit: InFlightDepositBalance tracking**
   - Incremented by 32 ETH per deposit in `depositToConsensusLayerWithDepositRoot`
   - Decremented when oracle reports new validators
   - Multiple deposits in single call tracked correctly
   - Underflow protection (floors at 0)

2. **Unit: _assetBalance() without count arithmetic**
   - Returns correct value with InFlightDepositBalance > 0
   - No branching on depositedCount vs clCount
   - Consistent with old calculation for same state

3. **Unit: ETH-based exit demand**
   - `demandExitBalance(ethAmount)` increments `CurrentExitDemandBalance`
   - `fillExitDemandBalance(ethAmount)` decrements correctly
   - Underflow protection

4. **Unit: requestFullExits**
   - Only keeper
   - `PendingFullExitBalance` incremented by sum of `expectedBalance`
   - `CurrentExitDemandBalance` decremented
   - Operator-level counts still updated

5. **Unit: Oracle reconciliation of full exits**
   - `PendingFullExitBalance` decremented by exited amount increase
   - Underflow protection

6. **Unit: preExitingBalance is ETH-based**
   - Uses `PendingFullExitBalance` not count * 32
   - Exit demand calculation in ETH

7. **Unit: Unsolicited exits**
   - `CurrentExitDemandBalance` decremented alongside count-based demand
   - Conservative estimate doesn't under-count

8. **Integration: Full lifecycle**
   - Deposit → InFlightDepositBalance goes up → oracle activates → goes down
   - Redeem demand → exit demand in ETH → keeper requests exits with actual balances → oracle reports → PendingFullExitBalance reconciled

9. **Migration: initRiverV1_3**
   - InFlightDepositBalance correctly initialized from current state
   - CurrentExitDemandBalance correctly initialized from count-based demand
   - _assetBalance() returns same value before and after migration

---

## Files Created/Modified Summary

| Action | File |
|--------|------|
| **Create** | `contracts/src/state/river/InFlightDepositBalance.sol` |
| **Create** | `contracts/src/state/river/PendingFullExitBalance.sol` |
| **Create** | `contracts/src/state/operatorsRegistry/CurrentExitDemandBalance.sol` |
| **Modify** | `contracts/src/components/ConsensusLayerDepositManager.1.sol` — call `_increaseInFlightDepositBalance()` after deposits |
| **Modify** | `contracts/src/components/OracleManager.1.sol` — call `_decreaseInFlightDepositBalance()` on new validators, `_reconcileFullExits()` on exited balance increase |
| **Modify** | `contracts/src/River.1.sol` — `_assetBalance()` uses `InFlightDepositBalance`, new `_increaseInFlightDepositBalance()`, `_decreaseInFlightDepositBalance()`, `_reconcileFullExits()`, `requestFullExits()`, modified exit demand calc, `initRiverV1_3()` |
| **Modify** | `contracts/src/OperatorsRegistry.1.sol` — new `demandExitBalance()`, `fillExitDemandBalance()`, `getCurrentExitDemandBalance()`, unsolicited exit ETH handling, `initOperatorsRegistryV1_3()` |
| **Modify** | `contracts/src/interfaces/IRiver.1.sol` — new structs, functions, events |
| **Modify** | `contracts/src/interfaces/IOperatorRegistry.1.sol` — new functions, events |
| **Create** | Test files |

---

## What DEPOSIT_SIZE is still used for (deposit mechanics only)

| Location | Use | Why it stays |
|----------|-----|-------------|
| `ConsensusLayerDepositManager._depositValidator()` | Deposit exactly 32 ETH to beacon contract | Beacon chain requires 32 ETH deposits |
| `ConsensusLayerDepositManager.depositToConsensusLayer()` | `committedBalance / DEPOSIT_SIZE` = max deposits | Need to know how many 32 ETH deposits fit |
| `River._commitBalanceToDeposit()` | Round to multiples of 32 ETH | Committed balance must be exact multiples |
| `River._increaseInFlightDepositBalance()` | `+= DEPOSIT_SIZE * count` | Each deposit adds exactly 32 ETH |
| `River._decreaseInFlightDepositBalance()` | `newValidators * DEPOSIT_SIZE` | Each activated validator was deposited at 32 ETH |

All of these are **deposit mechanical facts** — the beacon deposit contract requires exactly 32 ETH per validator. This is not a balance accounting assumption.

## What is NO LONGER used for accounting

| Old | New |
|-----|-----|
| `(depositedCount - clCount) * 32` in `_assetBalance()` | `InFlightDepositBalance.get()` |
| `(requestedExits - stopped) * 32` for pre-exiting | `PendingFullExitBalance.get()` |
| `ceil(shortfall / 32)` for exit demand count | `shortfall` ETH directly via `demandExitBalance()` |
| `demandValidatorExits(count)` | `demandExitBalance(ethAmount)` |
