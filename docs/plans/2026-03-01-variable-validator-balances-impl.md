# Variable Validator Balances Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace count-based validator accounting with ETH-denominated balances to support EIP-7251 variable effective balances (32-2048 ETH).

**Architecture:** New state libraries track cumulative deposited/activated ETH instead of validator counts. The deposit function accepts keeper-provided pubkeys+signatures+amounts. The oracle report adds `newlyActivatedDepositedBalance` and `stoppedBalancePerOperator` fields. A new `Operators.3.sol` struct replaces uint32 count fields with uint256 balance fields. Migration multiplies all existing counts by 32 ETH.

**Tech Stack:** Solidity 0.8.34, Foundry (forge), existing unstructured storage pattern

---

## Task 1: New State Libraries

Create the four new state storage libraries following the exact pattern in `contracts/src/state/river/DepositedValidatorCount.sol`.

**Files:**
- Create: `contracts/src/state/river/DepositedBalance.sol`
- Create: `contracts/src/state/river/ActivatedDepositedBalance.sol`
- Create: `contracts/src/state/operatorsRegistry/CurrentExitDemand.sol`
- Create: `contracts/src/state/operatorsRegistry/TotalExitsRequested.sol`

**Step 1: Create DepositedBalance.sol**

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Deposited Balance Storage
/// @notice Tracks cumulative ETH sent to the CL deposit contract (replaces DepositedValidatorCount)
library DepositedBalance {
    bytes32 internal constant DEPOSITED_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.depositedBalance")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(DEPOSITED_BALANCE_SLOT);
    }

    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(DEPOSITED_BALANCE_SLOT, _newValue);
    }
}
```

**Step 2: Create ActivatedDepositedBalance.sol**

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Activated Deposited Balance Storage
/// @notice Cumulative original deposit amounts for validators confirmed activated by oracle
library ActivatedDepositedBalance {
    bytes32 internal constant ACTIVATED_DEPOSITED_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.activatedDepositedBalance")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(ACTIVATED_DEPOSITED_BALANCE_SLOT);
    }

    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(ACTIVATED_DEPOSITED_BALANCE_SLOT, _newValue);
    }
}
```

**Step 3: Create CurrentExitDemand.sol**

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Current Exit Demand Storage
/// @notice ETH-denominated exit demand that still needs to be fulfilled (replaces CurrentValidatorExitsDemand)
library CurrentExitDemand {
    bytes32 internal constant CURRENT_EXIT_DEMAND_SLOT =
        bytes32(uint256(keccak256("river.state.currentExitDemand")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CURRENT_EXIT_DEMAND_SLOT);
    }

    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(CURRENT_EXIT_DEMAND_SLOT, _newValue);
    }
}
```

**Step 4: Create TotalExitsRequested.sol**

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Total Exits Requested Storage
/// @notice Cumulative ETH amount of exit requests performed (replaces TotalValidatorExitsRequested)
library TotalExitsRequested {
    bytes32 internal constant TOTAL_EXITS_REQUESTED_SLOT =
        bytes32(uint256(keccak256("river.state.totalExitsRequested")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(TOTAL_EXITS_REQUESTED_SLOT);
    }

    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(TOTAL_EXITS_REQUESTED_SLOT, _newValue);
    }
}
```

**Step 5: Verify compilation**

Run: `forge build`
Expected: All four libraries compile without errors.

**Step 6: Commit**

```bash
git add contracts/src/state/river/DepositedBalance.sol \
        contracts/src/state/river/ActivatedDepositedBalance.sol \
        contracts/src/state/operatorsRegistry/CurrentExitDemand.sol \
        contracts/src/state/operatorsRegistry/TotalExitsRequested.sol
git commit -m "feat: add ETH-denominated state libraries for variable validator balances"
```

---

## Task 2: Operators.3.sol — New Operator Struct

Create the new operator storage library with uint256 balance fields replacing uint32 count fields.

**Files:**
- Create: `contracts/src/state/operatorsRegistry/Operators.3.sol`
- Reference: `contracts/src/state/operatorsRegistry/Operators.2.sol`

**Step 1: Create Operators.3.sol**

Use a new storage slot so it doesn't collide with V2. The struct drops `limit`, `keys`, and `latestKeysEditBlockNumber` (key storage is removed). It replaces `funded` (uint32) with `fundedBalance` (uint256) and `requestedExits` (uint32) with `requestedExitBalance` (uint256).

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";

/// @title Operators Storage V3
/// @notice Operator struct with ETH-denominated balance fields for MaxEB support
library OperatorsV3 {
    bytes32 internal constant OPERATORS_SLOT = bytes32(uint256(keccak256("river.state.v3.operators")) - 1);

    struct Operator {
        /// @custom:attribute Total ETH deposited for this operator (wei)
        uint256 fundedBalance;
        /// @custom:attribute Total ETH requested to exit for this operator (wei)
        uint256 requestedExitBalance;
        /// @custom:attribute True if the operator is active
        bool active;
        /// @custom:attribute Display name of the operator
        string name;
        /// @custom:attribute Address of the operator
        address operator;
    }

    struct SlotOperator {
        Operator[] value;
    }

    error OperatorNotFound(uint256 index);

    function get(uint256 _index) internal view returns (Operator storage) {
        bytes32 slot = OPERATORS_SLOT;
        SlotOperator storage r;
        assembly {
            r.slot := slot
        }
        if (r.value.length <= _index) {
            revert OperatorNotFound(_index);
        }
        return r.value[_index];
    }

    function getAll() internal view returns (Operator[] storage) {
        bytes32 slot = OPERATORS_SLOT;
        SlotOperator storage r;
        assembly {
            r.slot := slot
        }
        return r.value;
    }

    function getCount() internal view returns (uint256) {
        bytes32 slot = OPERATORS_SLOT;
        SlotOperator storage r;
        assembly {
            r.slot := slot
        }
        return r.value.length;
    }

    function push(Operator memory _newOperator) internal returns (uint256) {
        LibSanitize._notZeroAddress(_newOperator.operator);
        LibSanitize._notEmptyString(_newOperator.name);
        bytes32 slot = OPERATORS_SLOT;
        SlotOperator storage r;
        assembly {
            r.slot := slot
        }
        r.value.push(_newOperator);
        return r.value.length;
    }

    /// @notice Stopped balances storage (ETH-denominated, replaces stopped validator counts)
    bytes32 internal constant STOPPED_BALANCES_SLOT =
        bytes32(uint256(keccak256("river.state.stoppedBalances")) - 1);

    struct SlotStoppedBalances {
        uint256[] value;
    }

    function getStoppedBalances() internal view returns (uint256[] storage) {
        bytes32 slot = STOPPED_BALANCES_SLOT;
        SlotStoppedBalances storage r;
        assembly {
            r.slot := slot
        }
        return r.value;
    }

    function setRawStoppedBalances(uint256[] memory value) internal {
        bytes32 slot = STOPPED_BALANCES_SLOT;
        SlotStoppedBalances storage r;
        assembly {
            r.slot := slot
        }
        r.value = value;
    }

    function _getStoppedBalanceAtIndex(uint256[] storage stoppedBalances, uint256 index)
        internal
        view
        returns (uint256)
    {
        if (index + 1 >= stoppedBalances.length) {
            return 0;
        }
        return stoppedBalances[index + 1];
    }
}
```

**Step 2: Verify compilation**

Run: `forge build`
Expected: Compiles without errors.

**Step 3: Commit**

```bash
git add contracts/src/state/operatorsRegistry/Operators.3.sol
git commit -m "feat: add Operators.3.sol with ETH-denominated balance fields"
```

---

## Task 3: Update Oracle Report Structs

Add `newlyActivatedDepositedBalance` and replace `stoppedValidatorCountPerOperator` with `stoppedBalancePerOperator` in the oracle report.

**Files:**
- Modify: `contracts/src/interfaces/components/IOracleManager.1.sol:105-164`

**Step 1: Update ConsensusLayerReport struct**

In `IOracleManager.1.sol`, update the `ConsensusLayerReport` struct (lines 106-151):

- Add `uint256 newlyActivatedDepositedBalance;` field after `validatorsCount`
- Replace `uint32[] stoppedValidatorCountPerOperator` with `uint256[] stoppedBalancePerOperator`

```solidity
struct ConsensusLayerReport {
    uint256 epoch;
    uint256 validatorsBalance;
    uint256 validatorsSkimmedBalance;
    uint256 validatorsExitedBalance;
    uint256 validatorsExitingBalance;
    uint32 validatorsCount;
    uint256 newlyActivatedDepositedBalance;
    uint256[] stoppedBalancePerOperator;
    bool rebalanceDepositToRedeemMode;
    bool slashingContainmentMode;
}
```

**Step 2: Update StoredConsensusLayerReport struct**

In the same file (lines 155-164), add the `newlyActivatedDepositedBalance` field:

```solidity
struct StoredConsensusLayerReport {
    uint256 epoch;
    uint256 validatorsBalance;
    uint256 validatorsSkimmedBalance;
    uint256 validatorsExitedBalance;
    uint256 validatorsExitingBalance;
    uint32 validatorsCount;
    bool rebalanceDepositToRedeemMode;
    bool slashingContainmentMode;
}
```

Note: `StoredConsensusLayerReport` does not need `newlyActivatedDepositedBalance` because it's a delta applied during processing (not stored). It also does not include the stopped array (same as today — it's stored separately in `OperatorsV3`).

**Step 3: Verify compilation (expect errors — downstream consumers haven't been updated yet)**

Run: `forge build 2>&1 | head -30`
Expected: Compilation errors in OracleManager.1.sol and River.1.sol referencing old field names. This confirms the struct change propagated.

**Step 4: Commit**

```bash
git add contracts/src/interfaces/components/IOracleManager.1.sol
git commit -m "feat: update oracle report structs for ETH-denominated balances"
```

---

## Task 4: Update IConsensusLayerDepositManager Interface

Replace the deposit function signature and add the `ValidatorDeposit` struct.

**Files:**
- Modify: `contracts/src/interfaces/components/IConsensusLayerDepositManager.1.sol`
- Modify: `contracts/src/interfaces/IOperatorRegistry.1.sol:10-16`

**Step 1: Add ValidatorDeposit struct and update interface**

In `IConsensusLayerDepositManager.1.sol`, replace the `OperatorAllocation`-based deposit function:

- Add `ValidatorDeposit` struct
- Replace `depositToConsensusLayerWithDepositRoot` with `depositToConsensusLayer`
- Replace `SetDepositedValidatorCount` event with `SetDepositedBalance`
- Add deposit bounds errors
- Replace `getDepositedValidatorCount()` with `getDepositedBalance()`
- Add `getActivatedDepositedBalance()` getter

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface IConsensusLayerDepositManagerV1 {
    /// @notice A single validator deposit with keeper-provided key, signature, and amount
    struct ValidatorDeposit {
        bytes pubkey;
        bytes signature;
        uint256 depositAmount;
        uint256 operatorIndex;
    }

    event SetDepositContractAddress(address indexed depositContract);
    event SetWithdrawalCredentials(bytes32 withdrawalCredentials);
    event SetDepositedBalance(uint256 oldDepositedBalance, uint256 newDepositedBalance);

    error NotEnoughFunds();
    error InconsistentPublicKeys();
    error InconsistentSignatures();
    error InvalidWithdrawalCredentials();
    error ErrorOnDeposit();
    error InvalidDepositRoot();
    error OnlyKeeper();
    error DepositAmountTooLow(uint256 amount, uint256 minimum);
    error DepositAmountTooHigh(uint256 amount, uint256 maximum);
    error DepositAmountNotGweiAligned(uint256 amount);
    error DepositsExceedCommittedBalance(uint256 totalAmount, uint256 committedBalance);
    error EmptyDepositsArray();

    function getBalanceToDeposit() external view returns (uint256);
    function getCommittedBalance() external view returns (uint256);
    function getWithdrawalCredentials() external view returns (bytes32);
    function getDepositedBalance() external view returns (uint256);
    function getActivatedDepositedBalance() external view returns (uint256);
    function getKeeper() external view returns (address);

    /// @notice Deposits ETH to the Consensus Layer with keeper-provided keys and signatures
    /// @param _deposits Array of validator deposits with pubkey, signature, amount, and operator index
    /// @param _depositRoot Expected deposit contract root for front-running protection
    function depositToConsensusLayer(
        ValidatorDeposit[] calldata _deposits,
        bytes32 _depositRoot
    ) external;
}
```

**Step 2: Add ExitAllocation struct to IOperatorsRegistryV1**

In `IOperatorRegistry.1.sol`, replace or add alongside `OperatorAllocation`:

```solidity
/// @notice Structure representing an ETH-denominated exit allocation
struct ExitAllocation {
    uint256 operatorIndex;
    uint256 exitBalance;
}
```

Keep `OperatorAllocation` for now (it's still referenced in tests) but it will be removed in a later task when the registry is cleaned up.

**Step 3: Verify compilation (expect errors from implementation files)**

Run: `forge build 2>&1 | head -30`
Expected: Errors from `ConsensusLayerDepositManager.1.sol` and `River.1.sol`.

**Step 4: Commit**

```bash
git add contracts/src/interfaces/components/IConsensusLayerDepositManager.1.sol \
        contracts/src/interfaces/IOperatorRegistry.1.sol
git commit -m "feat: update deposit and exit interfaces for variable balances"
```

---

## Task 5: Rewrite ConsensusLayerDepositManager

Replace the deposit logic to accept `ValidatorDeposit[]` with variable amounts.

**Files:**
- Modify: `contracts/src/components/ConsensusLayerDepositManager.1.sol`

**Step 1: Update imports and constants**

Replace `DepositedValidatorCount` import with `DepositedBalance` and `ActivatedDepositedBalance`. Replace `DEPOSIT_SIZE` with `MIN_DEPOSIT_SIZE` and `MAX_DEPOSIT_SIZE`.

**Step 2: Rewrite the deposit function**

Replace `depositToConsensusLayerWithDepositRoot` with `depositToConsensusLayer`. The new function:

1. Validates keeper caller
2. Validates deposit root
3. Iterates through `_deposits`, validating each amount (min/max/gwei-aligned)
4. Sums total deposit amount, checks against `CommittedBalance`
5. Calls `_depositValidator` for each deposit with the variable amount
6. Updates `CommittedBalance`, `DepositedBalance`
7. Returns operator-level funding deltas for the caller (River) to update OperatorsRegistry

**Step 3: Update `_depositValidator` to accept variable amounts**

Change `uint256 value = DEPOSIT_SIZE;` to `uint256 value = _depositAmount;` and add the amount parameter. The deposit data root calculation already uses the amount — it just needs to use the variable amount instead of the constant.

```solidity
function _depositValidator(
    bytes memory _publicKey,
    bytes memory _signature,
    bytes32 _withdrawalCredentials,
    uint256 _depositAmount
) internal {
    if (_publicKey.length != PUBLIC_KEY_LENGTH) {
        revert InconsistentPublicKeys();
    }
    if (_signature.length != SIGNATURE_LENGTH) {
        revert InconsistentSignatures();
    }

    uint256 depositAmountGwei = _depositAmount / 1 gwei;

    bytes32 pubkeyRoot = sha256(bytes.concat(_publicKey, bytes16(0)));
    bytes32 signatureRoot = sha256(
        bytes.concat(
            sha256(LibBytes.slice(_signature, 0, 64)),
            sha256(bytes.concat(LibBytes.slice(_signature, 64, SIGNATURE_LENGTH - 64), bytes32(0)))
        )
    );

    bytes32 depositDataRoot = sha256(
        bytes.concat(
            sha256(bytes.concat(pubkeyRoot, _withdrawalCredentials)),
            sha256(bytes.concat(bytes32(LibUint256.toLittleEndian64(depositAmountGwei)), signatureRoot))
        )
    );

    uint256 targetBalance = address(this).balance - _depositAmount;

    IDepositContract(DepositContractAddress.get()).deposit{value: _depositAmount}(
        _publicKey, abi.encodePacked(_withdrawalCredentials), _signature, depositDataRoot
    );
    if (address(this).balance != targetBalance) {
        revert ErrorOnDeposit();
    }
}
```

**Step 4: Update `getDepositedValidatorCount` to `getDepositedBalance`**

```solidity
function getDepositedBalance() external view returns (uint256) {
    return DepositedBalance.get();
}

function getActivatedDepositedBalance() external view returns (uint256) {
    return ActivatedDepositedBalance.get();
}
```

**Step 5: Remove `_getNextValidators` virtual method**

This is no longer needed — the keeper provides keys directly. Remove the virtual declaration and any override in River.

**Step 6: Verify compilation**

Run: `forge build 2>&1 | head -30`
Expected: Errors in `River.1.sol` (still referencing old deposit interface). ConsensusLayerDepositManager should compile.

**Step 7: Commit**

```bash
git add contracts/src/components/ConsensusLayerDepositManager.1.sol
git commit -m "feat: rewrite deposit manager for variable-amount deposits"
```

---

## Task 6: Update OracleManager Report Processing

Update `setConsensusLayerData` to handle the new report format and track `ActivatedDepositedBalance`.

**Files:**
- Modify: `contracts/src/components/OracleManager.1.sol:258-439`

**Step 1: Update imports**

Add imports for `DepositedBalance`, `ActivatedDepositedBalance`. Remove `DepositedValidatorCount` import (keep if needed for migration reference).

**Step 2: Remove `_DEPOSIT_SIZE` constant (line 26)**

This constant is no longer needed in OracleManager.

**Step 3: Update report validation (lines 297-305)**

Replace the validator count check:

```solidity
// Old: _report.validatorsCount > DepositedValidatorCount.get()
// New: validate activated deposit balance
uint256 newActivatedBalance = ActivatedDepositedBalance.get() + _report.newlyActivatedDepositedBalance;
if (newActivatedBalance > DepositedBalance.get()) {
    revert ActivatedBalanceExceedsDeposited(newActivatedBalance, DepositedBalance.get());
}
```

Keep the `validatorsCount` monotonic check as informational validation.

**Step 4: Update ActivatedDepositedBalance after validation**

After storing the report, increment the activated balance:

```solidity
ActivatedDepositedBalance.set(newActivatedBalance);
```

**Step 5: Update the `_requestExitsBasedOnRedeemDemandAfterRebalancings` call (line 421-426)**

Change the parameter from `_report.stoppedValidatorCountPerOperator` to `_report.stoppedBalancePerOperator`:

```solidity
_requestExitsBasedOnRedeemDemandAfterRebalancings(
    _report.validatorsExitingBalance,
    _report.stoppedBalancePerOperator,
    _report.rebalanceDepositToRedeemMode,
    _report.slashingContainmentMode
);
```

**Step 6: Update the virtual function signature for `_requestExitsBasedOnRedeemDemandAfterRebalancings`**

Change `uint32[] memory _stoppedValidatorCounts` to `uint256[] memory _stoppedBalances`.

**Step 7: Verify compilation**

Run: `forge build 2>&1 | head -30`

**Step 8: Commit**

```bash
git add contracts/src/components/OracleManager.1.sol
git commit -m "feat: update oracle manager for ETH-denominated report processing"
```

---

## Task 7: Update River._assetBalance() and _commitBalanceToDeposit()

The core accounting changes in River.

**Files:**
- Modify: `contracts/src/River.1.sol:392-404` (`_assetBalance`)
- Modify: `contracts/src/River.1.sol:579-610` (`_commitBalanceToDeposit`)
- Modify: `contracts/src/River.1.sol:508-566` (`_requestExitsBasedOnRedeemDemandAfterRebalancings`)

**Step 1: Update imports**

Add `DepositedBalance`, `ActivatedDepositedBalance`. Remove `DepositedValidatorCount`.

**Step 2: Rewrite `_assetBalance()` (lines 392-404)**

```solidity
function _assetBalance() internal view override(SharesManagerV1, OracleManagerV1) returns (uint256) {
    IOracleManagerV1.StoredConsensusLayerReport storage storedReport = LastConsensusLayerReport.get();
    uint256 pendingBalance = DepositedBalance.get() - ActivatedDepositedBalance.get();

    return storedReport.validatorsBalance
        + pendingBalance
        + BalanceToDeposit.get()
        + CommittedBalance.get()
        + BalanceToRedeem.get();
}
```

**Step 3: Remove DEPOSIT_SIZE rounding in `_commitBalanceToDeposit()` (line 604)**

Delete line 604: `currentMaxCommittableAmount = (currentMaxCommittableAmount / DEPOSIT_SIZE) * DEPOSIT_SIZE;`

Any amount can now be committed. The keeper decides deposit sizes.

**Step 4: Rewrite `_requestExitsBasedOnRedeemDemandAfterRebalancings` (lines 508-566)**

Update the parameter type from `uint32[]` to `uint256[]`. Replace the count-based exit logic with ETH-based:

```solidity
function _requestExitsBasedOnRedeemDemandAfterRebalancings(
    uint256 _exitingBalance,
    uint256[] memory _stoppedBalances,
    bool _depositToRedeemRebalancingAllowed,
    bool _slashingContainmentModeEnabled
) internal override {
    IOperatorsRegistryV1(OperatorsRegistryAddress.get())
        .reportStoppedBalances(_stoppedBalances, DepositedBalance.get());

    if (_slashingContainmentModeEnabled) {
        return;
    }

    uint256 totalSupply = _totalSupply();
    if (totalSupply > 0) {
        uint256 availableBalanceToRedeem = BalanceToRedeem.get();
        uint256 availableBalanceToDeposit = BalanceToDeposit.get();
        uint256 redeemManagerDemandInEth =
            _balanceFromShares(IRedeemManagerV1(RedeemManagerAddress.get()).getRedeemDemand());

        if (availableBalanceToRedeem + _exitingBalance < redeemManagerDemandInEth) {
            if (_depositToRedeemRebalancingAllowed && availableBalanceToDeposit > 0) {
                uint256 rebalancingAmount = LibUint256.min(
                    availableBalanceToDeposit,
                    redeemManagerDemandInEth - _exitingBalance - availableBalanceToRedeem
                );
                if (rebalancingAmount > 0) {
                    availableBalanceToRedeem += rebalancingAmount;
                    _setBalanceToRedeem(availableBalanceToRedeem);
                    _setBalanceToDeposit(availableBalanceToDeposit - rebalancingAmount);
                }
            }

            IOperatorsRegistryV1 or_ = IOperatorsRegistryV1(OperatorsRegistryAddress.get());

            (uint256 totalStoppedBalance, uint256 totalRequestedExitBalance) =
                or_.getStoppedAndRequestedExitBalances();

            // Pre-exiting balance: ETH requested to exit but not yet stopped
            uint256 preExitingBalance = totalRequestedExitBalance > totalStoppedBalance
                ? totalRequestedExitBalance - totalStoppedBalance
                : 0;

            if (availableBalanceToRedeem + _exitingBalance + preExitingBalance < redeemManagerDemandInEth) {
                uint256 exitDemandInEth =
                    redeemManagerDemandInEth - (availableBalanceToRedeem + _exitingBalance + preExitingBalance);

                or_.demandExits(exitDemandInEth, DepositedBalance.get());
            }
        }
    }
}
```

**Step 5: Remove `_getNextValidators` override**

The virtual method from ConsensusLayerDepositManager is removed. Delete the override in River that calls the OperatorsRegistry.

**Step 6: Update River to call new deposit function**

River's `depositToConsensusLayerWithDepositRoot` override is replaced. The new deposit function on ConsensusLayerDepositManager handles operator funding directly, or River wraps it to update the OperatorsRegistry.

**Step 7: Verify compilation**

Run: `forge build 2>&1 | head -30`

**Step 8: Commit**

```bash
git add contracts/src/River.1.sol
git commit -m "feat: rewrite River accounting for ETH-denominated balances"
```

---

## Task 8: Update OperatorsRegistry for ETH-Denominated Exits

Strip key storage functions, update exit tracking to ETH.

**Files:**
- Modify: `contracts/src/OperatorsRegistry.1.sol`
- Modify: `contracts/src/interfaces/IOperatorRegistry.1.sol`

**Step 1: Update OperatorsRegistry imports**

Replace `OperatorsV2` with `OperatorsV3`. Replace `CurrentValidatorExitsDemand` with `CurrentExitDemand`. Replace `TotalValidatorExitsRequested` with `TotalExitsRequested`. Remove `ValidatorKeys` import.

**Step 2: Remove key storage functions**

Remove: `addValidators`, `removeValidators`, `pickNextValidatorsToDeposit`, `_getPerOperatorValidatorKeysForAllocations`, `_getFundedCountForOperatorIfFundable`, `_flattenByteArrays`, `forceFundedValidatorKeysEventEmission`.

**Step 3: Rewrite `requestValidatorExits` to use `ExitAllocation`**

Replace `OperatorAllocation` (with `validatorCount`) with `ExitAllocation` (with `exitBalance`). All count-based logic becomes ETH-based:

- `operator.requestedExits += uint32(count)` → `operator.requestedExitBalance += exitBalance`
- `count > (operator.funded - operator.requestedExits)` → `exitBalance > (operator.fundedBalance - operator.requestedExitBalance)`
- `CurrentValidatorExitsDemand` → `CurrentExitDemand`
- `TotalValidatorExitsRequested` → `TotalExitsRequested`

**Step 4: Rewrite `_setStoppedValidatorCounts` as `_setStoppedBalances`**

Same monotonically-increasing validation logic, but with `uint256[]` instead of `uint32[]` and using `operator.fundedBalance`/`operator.requestedExitBalance`.

**Step 5: Rewrite `demandValidatorExits` as `demandExits`**

```solidity
function demandExits(uint256 _amount, uint256 _depositedBalance) external onlyRiver {
    uint256 currentExitDemand = CurrentExitDemand.get();
    uint256 totalExitsRequested = TotalExitsRequested.get();
    _amount = LibUint256.min(
        _amount, _depositedBalance - (totalExitsRequested + currentExitDemand)
    );
    if (_amount > 0) {
        _setCurrentExitDemand(currentExitDemand, currentExitDemand + _amount);
    }
}
```

**Step 6: Rename `reportStoppedValidatorCounts` to `reportStoppedBalances`**

Update the public function signature and the internal call.

**Step 7: Update `getStoppedAndRequestedExitCounts` to `getStoppedAndRequestedExitBalances`**

Return ETH values from `OperatorsV3`.

**Step 8: Update IOperatorsRegistryV1 interface**

Remove key-related function declarations. Update exit-related function signatures to ETH-denominated. Update events.

**Step 9: Verify compilation**

Run: `forge build 2>&1 | head -30`

**Step 10: Commit**

```bash
git add contracts/src/OperatorsRegistry.1.sol \
        contracts/src/interfaces/IOperatorRegistry.1.sol
git commit -m "feat: rewrite operators registry for ETH-denominated exit tracking"
```

---

## Task 9: Migration Logic

Add the initializer that migrates count-based state to ETH-based state.

**Files:**
- Modify: `contracts/src/OperatorsRegistry.1.sol` (add `initOperatorsRegistryV2`)
- Modify: `contracts/src/River.1.sol` (add `initRiverV2` or appropriate version)

**Step 1: Write migration initializer for River**

```solidity
function initRiverV2() external init(2) {
    IOracleManagerV1.StoredConsensusLayerReport storage lastReport = LastConsensusLayerReport.get();

    // Migrate deposited balance: count * 32 ETH
    uint256 depositedCount = DepositedValidatorCount.get();
    DepositedBalance.set(depositedCount * 32 ether);

    // Migrate activated balance: oracle's validator count * 32 ETH
    ActivatedDepositedBalance.set(uint256(lastReport.validatorsCount) * 32 ether);
}
```

**Step 2: Write migration initializer for OperatorsRegistry**

```solidity
function initOperatorsRegistryV2() external init(2) {
    // Migrate exit demand
    CurrentExitDemand.set(CurrentValidatorExitsDemand.get() * 32 ether);
    TotalExitsRequested.set(TotalValidatorExitsRequested.get() * 32 ether);

    // Migrate per-operator balances from V2 to V3
    uint256 operatorCount = OperatorsV2.getCount();
    for (uint256 i = 0; i < operatorCount; ++i) {
        OperatorsV2.Operator storage v2Op = OperatorsV2.get(i);
        OperatorsV3.Operator memory v3Op = OperatorsV3.Operator({
            fundedBalance: uint256(v2Op.funded) * 32 ether,
            requestedExitBalance: uint256(v2Op.requestedExits) * 32 ether,
            active: v2Op.active,
            name: v2Op.name,
            operator: v2Op.operator
        });
        OperatorsV3.push(v3Op);
    }

    // Migrate stopped validator counts to stopped balances
    uint32[] storage stoppedCounts = OperatorsV2.getStoppedValidators();
    if (stoppedCounts.length > 0) {
        uint256[] memory stoppedBalances = new uint256[](stoppedCounts.length);
        for (uint256 i = 0; i < stoppedCounts.length; ++i) {
            stoppedBalances[i] = uint256(stoppedCounts[i]) * 32 ether;
        }
        OperatorsV3.setRawStoppedBalances(stoppedBalances);
    }
}
```

**Step 3: Verify compilation**

Run: `forge build`

**Step 4: Commit**

```bash
git add contracts/src/River.1.sol contracts/src/OperatorsRegistry.1.sol
git commit -m "feat: add migration initializers for count-to-ETH conversion"
```

---

## Task 10: Write Tests — State Libraries

**Files:**
- Create: `contracts/test/state/river/DepositedBalance.t.sol`

**Step 1: Write basic get/set tests for new state libraries**

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../../../src/state/river/DepositedBalance.sol";
import "../../../src/state/river/ActivatedDepositedBalance.sol";

contract DepositedBalanceTest is Test {
    function testGetSetDepositedBalance() public {
        assertEq(DepositedBalance.get(), 0);
        DepositedBalance.set(100 ether);
        assertEq(DepositedBalance.get(), 100 ether);
    }

    function testGetSetActivatedDepositedBalance() public {
        assertEq(ActivatedDepositedBalance.get(), 0);
        ActivatedDepositedBalance.set(64 ether);
        assertEq(ActivatedDepositedBalance.get(), 64 ether);
    }
}
```

**Step 2: Run tests**

Run: `forge test --match-contract DepositedBalanceTest -v`
Expected: PASS

**Step 3: Commit**

```bash
git add contracts/test/state/river/DepositedBalance.t.sol
git commit -m "test: add state library tests for DepositedBalance and ActivatedDepositedBalance"
```

---

## Task 11: Write Tests — Variable Deposit Flow

**Files:**
- Modify: `contracts/test/components/ConsensusLayerDepositManager.1.t.sol`

**Step 1: Write test for variable-amount deposit**

Test that the keeper can deposit validators with different amounts (32 ETH, 64 ETH, 256 ETH) and that `DepositedBalance` and `CommittedBalance` update correctly.

**Step 2: Write test for deposit validation**

- Test revert on amount below 32 ETH
- Test revert on amount above 2048 ETH
- Test revert on non-gwei-aligned amount
- Test revert on total exceeding committed balance
- Test revert on empty deposits array

**Step 3: Write test for operator funding**

Test that `operator.fundedBalance` increments correctly for each deposit.

**Step 4: Run tests**

Run: `forge test --match-contract ConsensusLayerDepositManager -v`
Expected: All PASS

**Step 5: Commit**

```bash
git add contracts/test/components/ConsensusLayerDepositManager.1.t.sol
git commit -m "test: add variable deposit flow tests"
```

---

## Task 12: Write Tests — Asset Balance Calculation

**Files:**
- Modify: `contracts/test/River.1.t.sol`

**Step 1: Write test for `_assetBalance` with pending deposits**

Scenario: `DepositedBalance = 128 ETH`, `ActivatedDepositedBalance = 64 ETH`, `validatorsBalance = 65 ETH` (1 ETH of compounded rewards). Verify `_assetBalance` returns `65 + 64 + balanceToDeposit + committedBalance + balanceToRedeem`.

**Step 2: Write test for `_assetBalance` with no pending deposits**

Scenario: `DepositedBalance == ActivatedDepositedBalance`. Verify pending gap is zero.

**Step 3: Write test for `_commitBalanceToDeposit` without 32 ETH rounding**

Verify that non-multiple-of-32 amounts can be committed.

**Step 4: Run tests**

Run: `forge test --match-contract RiverV1 -v`
Expected: All PASS

**Step 5: Commit**

```bash
git add contracts/test/River.1.t.sol
git commit -m "test: add ETH-denominated asset balance tests"
```

---

## Task 13: Write Tests — Exit Flow

**Files:**
- Modify: `contracts/test/OperatorsRegistry.1.t.sol`

**Step 1: Write test for ETH-denominated exit request**

Scenario: Operator has `fundedBalance = 256 ETH`, keeper requests `exitBalance = 64 ETH`. Verify `requestedExitBalance` updates to 64 ETH.

**Step 2: Write test for exit demand calculation**

Verify that `demandExits` correctly caps at `depositedBalance - (totalExitsRequested + currentExitDemand)`.

**Step 3: Write test for stopped balance reporting**

Verify that `_setStoppedBalances` correctly detects unsolicited exits when `stoppedBalance > requestedExitBalance`.

**Step 4: Write test for exit validation errors**

- Test revert when exit exceeds funded-minus-requested
- Test revert when exit exceeds demand
- Test revert on unordered operator list

**Step 5: Run tests**

Run: `forge test --match-contract OperatorsRegistry -v`
Expected: All PASS

**Step 6: Commit**

```bash
git add contracts/test/OperatorsRegistry.1.t.sol
git commit -m "test: add ETH-denominated exit flow tests"
```

---

## Task 14: Write Tests — Migration

**Files:**
- Create: `contracts/test/migration/VariableBalanceMigration.t.sol`

**Step 1: Write migration test**

Set up V2 state with known values (e.g., 10 validators deposited, 3 operators with funded counts of 4/3/3, exit demand of 2). Run migration. Verify all ETH-denominated values are correct (multiply by 32 ETH).

**Step 2: Write migration idempotency test**

Verify that the init modifier prevents double-initialization.

**Step 3: Run tests**

Run: `forge test --match-contract VariableBalanceMigration -v`
Expected: All PASS

**Step 4: Commit**

```bash
git add contracts/test/migration/VariableBalanceMigration.t.sol
git commit -m "test: add migration tests for count-to-ETH conversion"
```

---

## Task 15: Full Build and Test Suite

**Step 1: Run full build**

Run: `forge build`
Expected: Clean compilation, no errors.

**Step 2: Run full test suite**

Run: `forge test`
Expected: All tests pass. If existing tests fail due to the interface changes, update them to use the new structs and function signatures.

**Step 3: Run formatter**

Run: `forge fmt`

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: fix remaining test compilation and formatting"
```

---

## Task Dependency Graph

```
Task 1 (state libs) ──┐
Task 2 (Operators.3) ─┤
Task 3 (oracle structs)┼──→ Task 6 (OracleManager) ──→ Task 7 (River) ──→ Task 8 (Registry) ──→ Task 9 (Migration)
Task 4 (interfaces) ───┘                                                                              │
                                                                                                       ↓
Task 10 (test state) ──→ Task 11 (test deposits) ──→ Task 12 (test balance) ──→ Task 13 (test exits) ──→ Task 14 (test migration) ──→ Task 15 (full suite)
```

Tasks 1-4 are independent foundations. Tasks 5-9 are sequential (each builds on the previous). Tasks 10-15 are sequential tests.
