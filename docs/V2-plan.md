---
shaping: true
---

# V2 Plan: Partial Exits via EIP-7002

**Parts:** A6, A7
**Demo:** Redeem demand → keeper triggers partial exits → funds arrive → redemption satisfied faster.
**Independent of V1** — can be developed in parallel.

---

## Step-by-step Implementation

### Step 1: New state storage

**File: `contracts/src/state/river/PendingPartialExitBalance.sol`**
```solidity
library PendingPartialExitBalance {
    bytes32 internal constant PENDING_PARTIAL_EXIT_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.pendingPartialExitBalance")) - 1);

    function get() internal view returns (uint256) { ... }
    function set(uint256 _newValue) internal { ... }
}
```

### Step 2: Withdraw contract — requestWithdrawal()

**File: `contracts/src/Withdraw.1.sol`**

New constant for the EIP-7002 withdrawal request system contract address:
```solidity
address public constant WITHDRAWAL_REQUEST_CONTRACT = 0x0c15F14308530b7CDB8460094BbB9cC28b9AaaAA;
// Actual address TBD — use the canonical Pectra system contract address
```

New function:
```solidity
/// @notice Submits a withdrawal request to the EIP-7002 system contract
/// @param _pubkey The 48-byte validator public key
/// @param _amountInGwei The withdrawal amount in gwei (0 = full exit)
function requestWithdrawal(bytes calldata _pubkey, uint64 _amountInGwei) external onlyRiver {
    if (_pubkey.length != 48) {
        revert InvalidPublicKeyLength();
    }

    // Encode request: pubkey (48 bytes) ++ amount (8 bytes, little-endian)
    bytes memory request = abi.encodePacked(_pubkey, _toLittleEndian64(_amountInGwei));

    // Get the current fee from the system contract
    // The fee is dynamic (EIP-1559-like) and must be read before calling
    uint256 fee = _getWithdrawalRequestFee();

    // Call the EIP-7002 system contract
    (bool success,) = WITHDRAWAL_REQUEST_CONTRACT.call{value: fee}(request);
    if (!success) {
        revert WithdrawalRequestFailed();
    }

    emit WithdrawalRequested(_pubkey, _amountInGwei, fee);
}

/// @notice Get the current EIP-7002 withdrawal request fee
function getWithdrawalRequestFee() external view returns (uint256) {
    return _getWithdrawalRequestFee();
}

function _getWithdrawalRequestFee() internal view returns (uint256) {
    // Read fee from system contract (first 32 bytes of static call return)
    (bool success, bytes memory data) = WITHDRAWAL_REQUEST_CONTRACT.staticcall("");
    if (!success || data.length < 32) {
        revert CannotReadWithdrawalFee();
    }
    return abi.decode(data, (uint256));
}

function _toLittleEndian64(uint64 _value) internal pure returns (bytes8) {
    // Convert uint64 to little-endian bytes8
    // Implementation follows LibUint256.toLittleEndian64 pattern
}
```

**File: `contracts/src/interfaces/IWithdraw.1.sol`**

Add:
- `requestWithdrawal(bytes calldata, uint64)` signature
- `getWithdrawalRequestFee()` view
- New events: `WithdrawalRequested`
- New errors: `InvalidPublicKeyLength`, `WithdrawalRequestFailed`, `CannotReadWithdrawalFee`

Version bump Withdraw to `1.3.0`.

### Step 3: River — new requestExits() function

**File: `contracts/src/River.1.sol`**

New structs (in interface):
```solidity
struct PartialExitRequest {
    bytes pubkey;       // 48 bytes
    uint64 amountInGwei;
}

struct ExitRequest {
    PartialExitRequest[] partialExits;
    IOperatorsRegistryV1.OperatorAllocation[] fullExits;
}
```

New function:
```solidity
/// @notice Keeper submits a mix of partial and full exit requests
/// @param _request The combined exit request
function requestExits(IRiverV1.ExitRequest calldata _request) external {
    if (msg.sender != KeeperAddress.get()) {
        revert OnlyKeeper();
    }

    uint256 totalPartialExitAmount = 0;

    // Process partial exits via Withdraw → EIP-7002
    IWithdrawV1 withdraw = IWithdrawV1(WithdrawalCredentials.getAddress());
    for (uint256 i = 0; i < _request.partialExits.length; ++i) {
        uint256 amount = uint256(_request.partialExits[i].amountInGwei) * 1 gwei;
        withdraw.requestWithdrawal(
            _request.partialExits[i].pubkey,
            _request.partialExits[i].amountInGwei
        );
        totalPartialExitAmount += amount;
    }

    // Track pending partial exits
    if (totalPartialExitAmount > 0) {
        PendingPartialExitBalance.set(
            PendingPartialExitBalance.get() + totalPartialExitAmount
        );
        emit PartialExitsRequested(totalPartialExitAmount, _request.partialExits.length);
    }

    // Process full exits via existing OperatorsRegistry flow
    if (_request.fullExits.length > 0) {
        IOperatorsRegistryV1(OperatorsRegistryAddress.get())
            .requestValidatorExits(_request.fullExits);
    }
}
```

### Step 4: Oracle report structs — add validatorsPartiallyExitedBalance

**File: `contracts/src/interfaces/components/IOracleManager.1.sol`**

Extend `ConsensusLayerReport`:
```solidity
uint256 validatorsPartiallyExitedBalance; // NEW: cumulative, non-decreasing
```

Extend `StoredConsensusLayerReport`:
```solidity
uint256 validatorsPartiallyExitedBalance; // NEW
```

### Step 5: OracleManager — partial exit reconciliation

**File: `contracts/src/components/OracleManager.1.sol`**

In `setConsensusLayerData`, after existing validations:

```solidity
// Validate partiallyExitedBalance is non-decreasing
if (_report.validatorsPartiallyExitedBalance < lastStoredReport.validatorsPartiallyExitedBalance) {
    revert InvalidDecreasingValidatorsPartiallyExitedBalance(
        lastStoredReport.validatorsPartiallyExitedBalance,
        _report.validatorsPartiallyExitedBalance
    );
}

uint256 partialExitIncrease = _report.validatorsPartiallyExitedBalance
    - lastStoredReport.validatorsPartiallyExitedBalance;
```

After storing the new report, reconcile:
```solidity
if (partialExitIncrease > 0) {
    _reconcilePartialExits(partialExitIncrease);
}
```

New virtual function:
```solidity
function _reconcilePartialExits(uint256 _partialExitIncrease) internal virtual;
```

Implemented in River.1.sol:
```solidity
function _reconcilePartialExits(uint256 _partialExitIncrease) internal override {
    uint256 currentPending = PendingPartialExitBalance.get();
    uint256 reconcileAmount = LibUint256.min(_partialExitIncrease, currentPending);
    PendingPartialExitBalance.set(currentPending - reconcileAmount);
    emit PartialExitsReconciled(_partialExitIncrease, reconcileAmount);
}
```

Update stored report:
```solidity
storedReport.validatorsPartiallyExitedBalance = _report.validatorsPartiallyExitedBalance;
```

### Step 6: Modified exit demand calculation

**File: `contracts/src/River.1.sol`** — `_requestExitsBasedOnRedeemDemandAfterRebalancings()`

**Prerequisite:** V0 (ETH-based accounting) must be in place. `PendingFullExitBalance` and `demandExitBalance(ethAmount)` replace count-based logic.

```solidity
// OLD (count-based):
// preExitingBalance = (requestedExits - stopped) * DEPOSIT_SIZE;
// validatorCountToExit = ceil(shortfall / DEPOSIT_SIZE);
// or.demandValidatorExits(validatorCountToExit);

// NEW (ETH-based, builds on V0):
uint256 preExitingBalance = PendingFullExitBalance.get() + PendingPartialExitBalance.get();

if (availableBalanceToRedeem + _exitingBalance + preExitingBalance < redeemManagerDemandInEth) {
    uint256 exitDemand = redeemManagerDemandInEth
        - (availableBalanceToRedeem + _exitingBalance + preExitingBalance);
    or.demandExitBalance(exitDemand);
}
```

Exit demand is now in ETH. The keeper fills the demand using a mix of partial + full exits with actual CL balances.

### Step 7: Fund routing for partial exits

**Important:** Partial exit funds arrive at the Withdraw contract as CL withdrawals (same as skimming/full exits). The oracle classifies them via `validatorsPartiallyExitedBalance`.

Currently, `_pullCLFunds` routes:
- Skimmed → `BalanceToDeposit`
- Exited → `BalanceToRedeem`

Partial exit funds should go to `BalanceToRedeem` (they're satisfying redeem demand). Two options:

**Option A:** Oracle reports partial exit funds within `validatorsExitedBalance` (mixed with full exits). Funds automatically go to `BalanceToRedeem`. `validatorsPartiallyExitedBalance` is used only for reconciling `PendingPartialExitBalance`.

**Option B:** Oracle reports partial exit funds as a separate flow, requiring `_pullCLFunds` to handle a third category.

**Recommend Option A** — simpler, no change to `_pullCLFunds`. The oracle includes partial exit amounts in both `validatorsExitedBalance` (for fund routing) and `validatorsPartiallyExitedBalance` (for pending balance reconciliation).

### Step 8: Interface updates

**File: `contracts/src/interfaces/IRiver.1.sol`**

Add:
- `ExitRequest` struct, `PartialExitRequest` struct
- `requestExits(ExitRequest)` signature
- `getPendingPartialExitBalance()` view
- New events: `PartialExitsRequested`, `PartialExitsReconciled`
- New errors: `InvalidDecreasingValidatorsPartiallyExitedBalance`

### Step 9: Withdraw contract — fund the EIP-7002 fee

The Withdraw contract needs ETH to pay EIP-7002 fees. It already holds ETH (exit/skimming funds). The fee is negligible in normal conditions, so the existing balance is sufficient.

If the Withdraw contract balance is too low to cover the fee (edge case), the `requestWithdrawal` call will revert. The keeper should check the fee before submitting.

Add a convenience function on River for the keeper:
```solidity
function getWithdrawalRequestFee() external view returns (uint256) {
    return IWithdrawV1(WithdrawalCredentials.getAddress()).getWithdrawalRequestFee();
}
```

### Step 10: Tests

1. **Unit: Withdraw.requestWithdrawal**
   - Only River can call
   - Invalid pubkey length reverts
   - Correct encoding (pubkey + LE amount)
   - Fee paid correctly
   - Event emitted

2. **Unit: River.requestExits**
   - Only keeper can call
   - Partial exits route through Withdraw
   - PendingPartialExitBalance incremented correctly
   - Full exits route through OperatorsRegistry
   - Mixed partial + full in single call

3. **Unit: Oracle partial exit reconciliation**
   - validatorsPartiallyExitedBalance delta decrements PendingPartialExitBalance
   - Non-decreasing validation
   - Underflow protection

4. **Unit: Modified preExitingBalance**
   - Includes PendingPartialExitBalance
   - Correctly reduces exit demand

5. **Integration: partial exit lifecycle**
   - Redeem demand created → keeper calls requestExits with partial exits → oracle reports → funds in BalanceToRedeem → redemption satisfied

6. **Integration: mixed partial + full exits**
   - Partial exits cover part of demand, full exits cover remainder

7. **Edge: EIP-7002 fee too high**
   - Keeper skips partial exits, only submits full exits

---

## Files Created/Modified Summary

| Action | File |
|--------|------|
| **Create** | `contracts/src/state/river/PendingPartialExitBalance.sol` |
| **Modify** | `contracts/src/Withdraw.1.sol` — `requestWithdrawal()`, `getWithdrawalRequestFee()`, version bump |
| **Modify** | `contracts/src/interfaces/IWithdraw.1.sol` — add new function signatures, events, errors |
| **Modify** | `contracts/src/interfaces/IRiver.1.sol` — add `ExitRequest` struct, `requestExits()`, events |
| **Modify** | `contracts/src/interfaces/components/IOracleManager.1.sol` — extend report structs |
| **Modify** | `contracts/src/components/OracleManager.1.sol` — partial exit reconciliation, new virtual fn |
| **Modify** | `contracts/src/River.1.sol` — `requestExits()`, `_reconcilePartialExits()`, modified `_requestExitsBasedOnRedeemDemandAfterRebalancings()`, `getWithdrawalRequestFee()` |
| **Create** | Test files for partial exit lifecycle |
