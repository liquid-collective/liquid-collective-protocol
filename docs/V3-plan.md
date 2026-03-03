---
shaping: true
---

# V3 Plan: Insolvency Protection

**Parts:** A8
**Demo:** Consolidation fails → detected (oracle or timeout) → buffer written down → CoverageFund donation → recovery.
**Depends on:** V1 (consolidation must be in place).

---

## Step-by-step Implementation

### Step 1: New state storage for configuration

**File: `contracts/src/state/river/MaxConsolidationDuration.sol`**
```solidity
library MaxConsolidationDuration {
    bytes32 internal constant MAX_CONSOLIDATION_DURATION_SLOT =
        bytes32(uint256(keccak256("river.state.maxConsolidationDuration")) - 1);

    function get() internal view returns (uint256) { ... }
    function set(uint256 _newValue) internal { ... }
}
```

**File: `contracts/src/state/river/MaxSingleConsolidationAmount.sol`**
```solidity
library MaxSingleConsolidationAmount {
    bytes32 internal constant MAX_SINGLE_CONSOLIDATION_AMOUNT_SLOT =
        bytes32(uint256(keccak256("river.state.maxSingleConsolidationAmount")) - 1);

    function get() internal view returns (uint256) { ... }
    function set(uint256 _newValue) internal { ... }
}
```

**File: `contracts/src/state/river/MaxTotalPendingConsolidation.sol`**
```solidity
library MaxTotalPendingConsolidation {
    bytes32 internal constant MAX_TOTAL_PENDING_CONSOLIDATION_SLOT =
        bytes32(uint256(keccak256("river.state.maxTotalPendingConsolidation")) - 1);

    function get() internal view returns (uint256) { ... }
    function set(uint256 _newValue) internal { ... }
}
```

### Step 2: Oracle report — add failedConsolidationIds

**File: `contracts/src/interfaces/components/IOracleManager.1.sol`**

Extend `ConsensusLayerReport`:
```solidity
struct ConsensusLayerReport {
    // ... existing fields (including V1 additions) ...
    uint32[] failedConsolidationIds; // NEW: request IDs of failed consolidations
}
```

Note: `StoredConsensusLayerReport` does NOT need this field — failed IDs are processed immediately and not stored.

### Step 3: River — writeDownFailedConsolidation()

**File: `contracts/src/River.1.sol`**

```solidity
/// @notice Write down a failed consolidation's pending balance
/// @dev Callable by admin (timeout path) or internally from oracle report
/// @param _requestId The consolidation request ID that failed
function writeDownFailedConsolidation(uint256 _requestId) external {
    // Allow admin or oracle
    if (msg.sender != Administrable._getAdmin() && msg.sender != OracleAddress.get()) {
        revert LibErrors.Unauthorized(msg.sender);
    }

    _writeDownConsolidation(_requestId);
}

function _writeDownConsolidation(uint256 _requestId) internal {
    // Load request
    ConsolidationRequest storage request = _getConsolidationRequest(_requestId);

    // Must be in PENDING status
    if (request.status != 1) { // 1 = PENDING
        revert InvalidConsolidationStatus(_requestId, request.status);
    }

    // For admin path: enforce timeout
    if (msg.sender == Administrable._getAdmin()) {
        uint256 maxDuration = MaxConsolidationDuration.get();
        if (block.timestamp < request.requestTimestamp + maxDuration) {
            revert ConsolidationNotTimedOut(_requestId, request.requestTimestamp, maxDuration);
        }
    }

    // Calculate failed amount (expected minus any already reconciled)
    uint256 failedAmount = request.expectedBalance - request.reconciledBalance;

    // Write down buffer
    uint256 currentPending = PendingConsolidationBalance.get();
    uint256 writedownAmount = LibUint256.min(failedAmount, currentPending);
    PendingConsolidationBalance.set(currentPending - writedownAmount);

    // Update request status
    request.status = 3; // FAILED

    emit ConsolidationFailed(_requestId, failedAmount, writedownAmount);
}
```

### Step 4: OracleManager — process failed consolidations in report

**File: `contracts/src/components/OracleManager.1.sol`**

In `setConsensusLayerData`, after consolidation reconciliation (from V1):

```solidity
// Process failed consolidations reported by oracle
if (_report.failedConsolidationIds.length > 0) {
    _processFailedConsolidations(_report.failedConsolidationIds);
}
```

New virtual function:
```solidity
function _processFailedConsolidations(uint32[] calldata _failedIds) internal virtual;
```

Implemented in River.1.sol:
```solidity
function _processFailedConsolidations(uint32[] calldata _failedIds) internal override {
    for (uint256 i = 0; i < _failedIds.length; ++i) {
        _writeDownConsolidation(uint256(_failedIds[i]));
    }
}
```

### Step 5: Consolidation caps — enforce in executeConsolidation()

**File: `contracts/src/River.1.sol`**

Add validation to `executeConsolidation()` (from V1):

```solidity
function executeConsolidation(uint256 _requestId, uint256 _expectedBalance) external {
    if (msg.sender != KeeperAddress.get()) revert OnlyKeeper();

    // NEW: Cap enforcement
    uint256 maxSingle = MaxSingleConsolidationAmount.get();
    if (maxSingle > 0 && _expectedBalance > maxSingle) {
        revert ConsolidationAmountExceedsCap(_expectedBalance, maxSingle);
    }

    uint256 maxTotal = MaxTotalPendingConsolidation.get();
    uint256 currentPending = PendingConsolidationBalance.get();
    if (maxTotal > 0 && currentPending + _expectedBalance > maxTotal) {
        revert TotalPendingConsolidationExceedsCap(currentPending + _expectedBalance, maxTotal);
    }

    // ... rest of executeConsolidation from V1 ...
}
```

### Step 6: Admin configuration functions

**File: `contracts/src/River.1.sol`**

```solidity
function setMaxConsolidationDuration(uint256 _duration) external onlyAdmin {
    MaxConsolidationDuration.set(_duration);
    emit SetMaxConsolidationDuration(_duration);
}

function setMaxSingleConsolidationAmount(uint256 _amount) external onlyAdmin {
    MaxSingleConsolidationAmount.set(_amount);
    emit SetMaxSingleConsolidationAmount(_amount);
}

function setMaxTotalPendingConsolidation(uint256 _amount) external onlyAdmin {
    MaxTotalPendingConsolidation.set(_amount);
    emit SetMaxTotalPendingConsolidation(_amount);
}

function getMaxConsolidationDuration() external view returns (uint256) {
    return MaxConsolidationDuration.get();
}

function getMaxSingleConsolidationAmount() external view returns (uint256) {
    return MaxSingleConsolidationAmount.get();
}

function getMaxTotalPendingConsolidation() external view returns (uint256) {
    return MaxTotalPendingConsolidation.get();
}
```

### Step 7: Initialization

**File: `contracts/src/River.1.sol`**

New init function for the Pectra upgrade:
```solidity
function initRiverV1_3(
    uint256 _maxConsolidationDuration,
    uint256 _maxSingleConsolidationAmount,
    uint256 _maxTotalPendingConsolidation
) external init(3) {
    MaxConsolidationDuration.set(_maxConsolidationDuration);
    emit SetMaxConsolidationDuration(_maxConsolidationDuration);

    MaxSingleConsolidationAmount.set(_maxSingleConsolidationAmount);
    emit SetMaxSingleConsolidationAmount(_maxSingleConsolidationAmount);

    MaxTotalPendingConsolidation.set(_maxTotalPendingConsolidation);
    emit SetMaxTotalPendingConsolidation(_maxTotalPendingConsolidation);
}
```

Suggested defaults:
- `maxConsolidationDuration`: 7 days (604800 seconds)
- `maxSingleConsolidationAmount`: 2048 ether (max effective balance post-Pectra)
- `maxTotalPendingConsolidation`: 10000 ether (adjustable based on CoverageFund capacity)

### Step 8: Interface updates

**File: `contracts/src/interfaces/IRiver.1.sol`**

Add:
- `writeDownFailedConsolidation(uint256)` signature
- `setMaxConsolidationDuration(uint256)`, `setMaxSingleConsolidationAmount(uint256)`, `setMaxTotalPendingConsolidation(uint256)` signatures
- Getter signatures for all three config values
- `initRiverV1_3()` signature
- New events: `ConsolidationFailed`, `SetMaxConsolidationDuration`, `SetMaxSingleConsolidationAmount`, `SetMaxTotalPendingConsolidation`
- New errors: `ConsolidationAmountExceedsCap`, `TotalPendingConsolidationExceedsCap`, `ConsolidationNotTimedOut`, `InvalidConsolidationStatus`

### Step 9: Tests

1. **Unit: writeDownFailedConsolidation (admin path)**
   - Only admin can call
   - Requires PENDING status
   - Enforces timeout (reverts if not expired)
   - PendingConsolidationBalance decremented correctly
   - Request status set to FAILED
   - Event emitted

2. **Unit: writeDownFailedConsolidation (oracle path)**
   - Oracle can call without timeout check
   - Processes failedConsolidationIds in report
   - Multiple failures in single report

3. **Unit: Consolidation caps**
   - maxSingleConsolidationAmount: executeConsolidation reverts if exceeded
   - maxTotalPendingConsolidation: executeConsolidation reverts if total would exceed
   - Caps of 0 = no cap (disabled)

4. **Unit: Admin configuration**
   - Only admin can set caps and duration
   - Events emitted
   - Getter functions return correct values

5. **Integration: full failure + recovery lifecycle**
   - executeConsolidation → wait for timeout → writeDownFailedConsolidation
   - Verify: _assetBalance() drops, conversion rate drops
   - CoverageFund.donate() → oracle report pulls coverage → _assetBalance() recovers

6. **Integration: oracle-detected failure**
   - executeConsolidation → oracle report with failedConsolidationIds
   - Verify: buffer written down, event emitted

7. **Edge: partial reconciliation then failure**
   - Consolidation partially reconciled (some ETH arrived) then reported failed
   - failedAmount = expectedBalance - reconciledBalance (not full amount)

8. **Edge: false positive recovery**
   - Consolidation written down as failed, then ETH arrives in later report
   - validatorsConsolidatedBalance increases → excess flows through as protocol gain

---

## Files Created/Modified Summary

| Action | File |
|--------|------|
| **Create** | `contracts/src/state/river/MaxConsolidationDuration.sol` |
| **Create** | `contracts/src/state/river/MaxSingleConsolidationAmount.sol` |
| **Create** | `contracts/src/state/river/MaxTotalPendingConsolidation.sol` |
| **Modify** | `contracts/src/interfaces/components/IOracleManager.1.sol` — add `failedConsolidationIds` to report |
| **Modify** | `contracts/src/interfaces/IRiver.1.sol` — add writedown, config, init functions + events/errors |
| **Modify** | `contracts/src/components/OracleManager.1.sol` — process `failedConsolidationIds`, new virtual fn |
| **Modify** | `contracts/src/River.1.sol` — `writeDownFailedConsolidation()`, `_processFailedConsolidations()`, cap enforcement in `executeConsolidation()`, admin config setters/getters, `initRiverV1_3()` |
| **Create** | Test files for insolvency protection |

---

## Recovery Timeline (Example)

```
Day 0:   executeConsolidation(id=5, 100 ETH)
         PendingConsolidationBalance: 0 → 100 ETH
         LsETH minted to user

Day 1:   Expected balance transfer. Nothing arrives.
         Oracle reports: validatorsConsolidatedBalance unchanged.
         PendingConsolidationBalance: still 100 ETH (inflating _assetBalance)

Day 7:   MAX_CONSOLIDATION_DURATION reached.
         Admin calls writeDownFailedConsolidation(5)
         PendingConsolidationBalance: 100 → 0 ETH
         _assetBalance() drops by 100 ETH
         Conversion rate drops proportionally (socialized loss)

Day 8:   Insurance entity donates 100 ETH to CoverageFund
         CoverageFund.donate{value: 100 ether}()

Day 8+:  Next oracle report:
         _pullCoverageFunds(availableAmountToUpperBound)
         BalanceToDeposit += pulled amount
         _assetBalance() partially recovers
         (May take multiple reports to fully recover due to upper bound)

Day ~14: Full recovery. Conversion rate restored.
```
