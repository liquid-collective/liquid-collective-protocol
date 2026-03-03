---
shaping: true
---

# V1 Plan: Validator Consolidation (Happy Path)

**Parts:** A1, A2, A3, A4, A5
**Demo:** User requests consolidation → keeper executes → LsETH minted → oracle reconciles → conversion rate unchanged.

---

## Step-by-step Implementation

### Step 1: New state storage files

Create unstructured storage libraries following existing pattern (e.g., `BalanceToDeposit.sol`).

**File: `contracts/src/state/river/PendingConsolidationBalance.sol`**
```solidity
library PendingConsolidationBalance {
    bytes32 internal constant PENDING_CONSOLIDATION_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.pendingConsolidationBalance")) - 1);

    function get() internal view returns (uint256) { ... }
    function set(uint256 _newValue) internal { ... }
}
```

**File: `contracts/src/state/river/ConsolidationRequests.sol`**

Storage for the consolidation request array and source→requestId mapping. This is more complex than a simple uint256 — needs a struct array and a mapping.

```solidity
struct ConsolidationRequest {
    bytes32 sourcePubkeyHash;
    bytes32 targetPubkeyHash;
    address recipient;
    uint256 expectedBalance;
    uint256 reconciledBalance;
    uint64 requestTimestamp;
    uint8 status; // 0=REQUESTED, 1=PENDING, 2=COMPLETED, 3=FAILED
}
```

Options for storage:
- **A)** Use a dedicated storage contract/library with unstructured storage for the array length and a mapping for elements (similar to `RedeemQueue.2.sol` pattern).
- **B)** Use a simpler mapping-based approach: `mapping(uint256 => ConsolidationRequest)` + counter.

Recommend **B** — simpler, no need for queue semantics. Consolidations are indexed by ID, not ordered.

**File: `contracts/src/state/river/ConsolidationRequestCount.sol`**
```solidity
library ConsolidationRequestCount {
    bytes32 internal constant CONSOLIDATION_REQUEST_COUNT_SLOT =
        bytes32(uint256(keccak256("river.state.consolidationRequestCount")) - 1);
    function get() internal view returns (uint256) { ... }
    function set(uint256 _newValue) internal { ... }
}
```

### Step 2: Allowlist — add CONSOLIDATION_MASK

**File: `contracts/src/libraries/LibAllowlistMasks.sol`**

Add:
```solidity
uint256 internal constant CONSOLIDATION_MASK = 0x8; // bit 4
```

No changes to Allowlist.1.sol itself — the bitmask system is generic.

### Step 3: Oracle report structs — add validatorsConsolidatedBalance

**File: `contracts/src/interfaces/components/IOracleManager.1.sol`**

Extend `ConsensusLayerReport`:
```solidity
struct ConsensusLayerReport {
    // ... existing fields ...
    uint256 validatorsConsolidatedBalance; // NEW: cumulative, non-decreasing
}
```

Extend `StoredConsensusLayerReport`:
```solidity
struct StoredConsensusLayerReport {
    // ... existing fields ...
    uint256 validatorsConsolidatedBalance; // NEW
}
```

### Step 4: River — requestConsolidation()

**File: `contracts/src/River.1.sol`**

New imports: `PendingConsolidationBalance`, `ConsolidationRequests` state, new interface methods.

```solidity
function requestConsolidation(
    bytes calldata _sourcePubkey,
    bytes calldata _targetPubkey
) external returns (uint256 requestId) {
    // 1. Allowlist check
    IAllowlistV1(AllowlistAddress.get()).onlyAllowed(msg.sender, LibAllowlistMasks.CONSOLIDATION_MASK);

    // 2. Validate pubkey lengths
    if (_sourcePubkey.length != PUBLIC_KEY_LENGTH) revert InvalidPublicKeyLength();
    if (_targetPubkey.length != PUBLIC_KEY_LENGTH) revert InvalidPublicKeyLength();

    // 3. Validate target belongs to LC (check OperatorsRegistry)
    // IOperatorsRegistryV1(OperatorsRegistryAddress.get()).isValidatorKey(_targetPubkey);

    // 4. Store request
    requestId = ConsolidationRequestCount.get();
    // Store ConsolidationRequest at requestId
    // { sourcePubkeyHash, targetPubkeyHash, msg.sender, 0, 0, 0, REQUESTED }
    ConsolidationRequestCount.set(requestId + 1);

    // 5. Index by source for oracle lookup
    // consolidationRequestBySource[keccak256(_sourcePubkey)] = requestId

    emit ConsolidationRequested(requestId, msg.sender, _sourcePubkey, _targetPubkey);
}
```

### Step 5: River — executeConsolidation()

```solidity
function executeConsolidation(
    uint256 _requestId,
    uint256 _expectedBalance
) external {
    // 1. Only keeper
    if (msg.sender != KeeperAddress.get()) revert OnlyKeeper();

    // 2. Load and validate request
    // request = consolidationRequests[_requestId]
    // require(request.status == REQUESTED)

    // 3. Record expected balance and update status
    // request.expectedBalance = _expectedBalance
    // request.requestTimestamp = uint64(block.timestamp)
    // request.status = PENDING

    // 4. Increment buffer (ATOMIC with minting)
    PendingConsolidationBalance.set(
        PendingConsolidationBalance.get() + _expectedBalance
    );

    // 5. Mint LsETH to recipient at current conversion rate
    uint256 mintedShares = SharesManagerV1._mintShares(request.recipient, _expectedBalance);

    // 6. Submit consolidation request to CL system contract
    //    via Withdraw contract (it's the withdrawal credentials address)
    //    OR directly if the source's withdrawal credentials initiate
    //    (depends on EIP-7251 exact mechanics)

    emit ConsolidationExecuted(_requestId, request.recipient, _expectedBalance, mintedShares);
}
```

### Step 6: River — modified _assetBalance()

**File: `contracts/src/River.1.sol`** (line ~392)

**Prerequisite:** V0 (ETH-based accounting) must be in place. `InFlightDepositBalance` replaces `(depositedCount - clCount) * 32`.

```solidity
function _assetBalance() internal view override returns (uint256) {
    IOracleManagerV1.StoredConsensusLayerReport storage storedReport = LastConsensusLayerReport.get();
    return storedReport.validatorsBalance
        + BalanceToDeposit.get()
        + CommittedBalance.get()
        + BalanceToRedeem.get()
        + PendingConsolidationBalance.get()   // NEW (V1)
        + InFlightDepositBalance.get();        // from V0 (replaces count * 32)
}
```

### Step 7: OracleManager — consolidation reconciliation in setConsensusLayerData

**File: `contracts/src/components/OracleManager.1.sol`**

In `setConsensusLayerData`, after pulling CL funds and before computing postReportUnderlyingBalance:

```solidity
// Reconcile consolidations
{
    uint256 lastConsolidatedBalance = lastStoredReport.validatorsConsolidatedBalance;
    if (_report.validatorsConsolidatedBalance < lastConsolidatedBalance) {
        revert InvalidDecreasingValidatorsConsolidatedBalance(
            lastConsolidatedBalance, _report.validatorsConsolidatedBalance
        );
    }
    uint256 consolidatedIncrease = _report.validatorsConsolidatedBalance - lastConsolidatedBalance;
    if (consolidatedIncrease > 0) {
        _reconcileConsolidations(consolidatedIncrease);
    }
}
```

New virtual function:
```solidity
function _reconcileConsolidations(uint256 _consolidatedIncrease) internal virtual;
```

Implemented in River.1.sol:
```solidity
function _reconcileConsolidations(uint256 _consolidatedIncrease) internal override {
    uint256 currentPending = PendingConsolidationBalance.get();
    uint256 reconcileAmount = LibUint256.min(_consolidatedIncrease, currentPending);
    PendingConsolidationBalance.set(currentPending - reconcileAmount);
    emit ConsolidationReconciled(_consolidatedIncrease, reconcileAmount);
}
```

Update stored report to include `validatorsConsolidatedBalance`:
```solidity
storedReport.validatorsConsolidatedBalance = _report.validatorsConsolidatedBalance;
```

### Step 8: Interface updates

**File: `contracts/src/interfaces/IRiver.1.sol`**

Add:
- `requestConsolidation()` signature
- `executeConsolidation()` signature
- `getConsolidationRequest(uint256 requestId)` view
- `getPendingConsolidationBalance()` view
- New events: `ConsolidationRequested`, `ConsolidationExecuted`, `ConsolidationReconciled`
- New errors: `InvalidPublicKeyLength`, `InvalidConsolidationStatus`, `InvalidDecreasingValidatorsConsolidatedBalance`

### Step 9: Version bump

**File: `contracts/src/River.1.sol`**

```solidity
function version() external pure returns (string memory) {
    return "1.3.0";
}
```

Also Withdraw.1.sol if modified in V2.

### Step 10: Tests

1. **Unit: requestConsolidation**
   - Allowlist check (CONSOLIDATION_MASK required, denied address reverts)
   - Invalid pubkey length reverts
   - Request stored correctly, ID incremented
   - Event emitted

2. **Unit: executeConsolidation**
   - Only keeper can call
   - Request must be in REQUESTED status
   - PendingConsolidationBalance incremented by expectedBalance
   - LsETH minted to recipient at correct conversion rate
   - Request status updated to PENDING

3. **Unit: _assetBalance()**
   - Returns correct value with PendingConsolidationBalance > 0
   - Combined with in-flight validators

4. **Unit: oracle reconciliation**
   - validatorsConsolidatedBalance delta decrements PendingConsolidationBalance
   - Underflow protection (min with current pending)
   - Conversion rate unaffected (delta cancels out)
   - Bounds check not tripped by consolidation

5. **Integration: full consolidation lifecycle**
   - requestConsolidation → executeConsolidation → oracle report with validatorsConsolidatedBalance increase
   - Verify: LsETH balance, conversion rate before/after, PendingConsolidationBalance = 0 after reconciliation

6. **Edge: multiple concurrent consolidations**
   - Two consolidations in flight, oracle reconciles both in one report

7. **Edge: oracle reports more consolidated than pending**
   - PendingConsolidationBalance floors at 0 (rogue/unexpected consolidation = gift to protocol)

---

## Files Created/Modified Summary

| Action | File |
|--------|------|
| **Create** | `contracts/src/state/river/PendingConsolidationBalance.sol` |
| **Create** | `contracts/src/state/river/ConsolidationRequests.sol` (struct + storage) |
| **Create** | `contracts/src/state/river/ConsolidationRequestCount.sol` |
| **Modify** | `contracts/src/libraries/LibAllowlistMasks.sol` — add `CONSOLIDATION_MASK` |
| **Modify** | `contracts/src/interfaces/components/IOracleManager.1.sol` — extend report structs |
| **Modify** | `contracts/src/interfaces/IRiver.1.sol` — add consolidation functions, events, errors |
| **Modify** | `contracts/src/River.1.sol` — `requestConsolidation`, `executeConsolidation`, `_assetBalance`, `_reconcileConsolidations`, version bump |
| **Modify** | `contracts/src/components/OracleManager.1.sol` — consolidation reconciliation in `setConsensusLayerData`, new virtual fn |
| **Create** | Test files for consolidation lifecycle |
