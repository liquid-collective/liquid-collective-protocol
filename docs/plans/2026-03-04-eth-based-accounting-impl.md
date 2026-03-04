# ETH-Based Accounting Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace validator-count-based accounting with direct ETH tracking to support EIP-7251 (MaxEB) variable deposit amounts.

**Architecture:** New `TotalDepositedETH` state variable tracks cumulative ETH deposited. The `_assetBalance()` formula replaces `(depositedCount - clCount) * 32` with `totalDepositedETH - (validatorsBalance + exitedBalance + skimmedBalance)`. The deposit flow accepts per-validator deposit amounts instead of a hardcoded 32 ETH.

**Tech Stack:** Solidity 0.8.34, Foundry (forge), unstructured storage pattern

---

### Task 1: Create TotalDepositedETH State Variable

**Files:**
- Create: `contracts/src/state/river/TotalDepositedETH.sol`

**Step 1: Create the state library**

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Total Deposited ETH Storage
/// @notice Utility to manage the Total Deposited ETH in storage
/// @notice Tracks the cumulative amount of ETH deposited to the consensus layer deposit contract
library TotalDepositedETH {
    /// @notice Storage slot of the Total Deposited ETH
    bytes32 internal constant TOTAL_DEPOSITED_ETH_SLOT =
        bytes32(uint256(keccak256("river.state.totalDepositedETH")) - 1);

    /// @notice Retrieve the Total Deposited ETH
    /// @return The Total Deposited ETH
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(TOTAL_DEPOSITED_ETH_SLOT);
    }

    /// @notice Sets the Total Deposited ETH
    /// @param _newValue New Total Deposited ETH
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(TOTAL_DEPOSITED_ETH_SLOT, _newValue);
    }
}
```

**Step 2: Verify it compiles**

Run: `cd contracts && forge build`
Expected: Compilation succeeds (no files import it yet, but the library itself should compile)

**Step 3: Commit**

```bash
git add contracts/src/state/river/TotalDepositedETH.sol
git commit -m "feat: add TotalDepositedETH state variable"
```

---

### Task 2: Update OperatorAllocation Struct

**Files:**
- Modify: `contracts/src/interfaces/IOperatorRegistry.1.sol:13-16`
- Modify: `contracts/test/OperatorAllocationTestBase.sol:9-35`

**Step 1: Add depositAmounts to OperatorAllocation**

In `contracts/src/interfaces/IOperatorRegistry.1.sol`, update the struct at lines 13-16:

```solidity
struct OperatorAllocation {
    uint256 operatorIndex;
    uint256 validatorCount;
    uint256[] depositAmounts;
}
```

**Step 2: Update test helper _createAllocation**

In `contracts/test/OperatorAllocationTestBase.sol`, update all `_createAllocation` overloads to include `depositAmounts`. The single-count helper:

```solidity
function _createAllocation(uint256 count) internal pure returns (IOperatorsRegistryV1.OperatorAllocation[] memory) {
    return _createAllocation(0, count, 32 ether);
}

function _createAllocation(uint256 operatorIndex, uint256 count)
    internal
    pure
    returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
{
    return _createAllocation(operatorIndex, count, 32 ether);
}

function _createAllocation(uint256 operatorIndex, uint256 count, uint256 depositAmount)
    internal
    pure
    returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
{
    IOperatorsRegistryV1.OperatorAllocation[] memory allocations = new IOperatorsRegistryV1.OperatorAllocation[](1);
    uint256[] memory amounts = new uint256[](count);
    for (uint256 i = 0; i < count; ++i) {
        amounts[i] = depositAmount;
    }
    allocations[0] = IOperatorsRegistryV1.OperatorAllocation({
        operatorIndex: operatorIndex,
        validatorCount: count,
        depositAmounts: amounts
    });
    return allocations;
}

function _createAllocation(uint256[] memory opIndexes, uint32[] memory counts)
    internal
    pure
    returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
{
    IOperatorsRegistryV1.OperatorAllocation[] memory allocations =
        new IOperatorsRegistryV1.OperatorAllocation[](opIndexes.length);
    for (uint256 i = 0; i < opIndexes.length; ++i) {
        uint256[] memory amounts = new uint256[](counts[i]);
        for (uint256 j = 0; j < counts[i]; ++j) {
            amounts[j] = 32 ether;
        }
        allocations[i] = IOperatorsRegistryV1.OperatorAllocation({
            operatorIndex: opIndexes[i],
            validatorCount: counts[i],
            depositAmounts: amounts
        });
    }
    return allocations;
}
```

**Step 3: Verify it compiles**

Run: `cd contracts && forge build`
Expected: Compilation succeeds (existing tests still use 32 ETH default)

**Step 4: Commit**

```bash
git add contracts/src/interfaces/IOperatorRegistry.1.sol contracts/test/OperatorAllocationTestBase.sol
git commit -m "feat: add depositAmounts to OperatorAllocation struct"
```

---

### Task 3: Update ConsensusLayerDepositManager for Variable Deposits

**Files:**
- Modify: `contracts/src/components/ConsensusLayerDepositManager.1.sol:94-196`

**Step 1: Write a failing test for variable deposit amounts**

Create or update test in `contracts/test/components/ConsensusLayerDepositManager.1.t.sol`. Add a new test contract or function that deposits with a non-32-ETH amount:

```solidity
function testDepositVariableAmount() public {
    vm.deal(address(depositManager), 64 ether);
    ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSyncBalance();
    // Create allocation with one validator at 64 ETH
    IOperatorsRegistryV1.OperatorAllocation[] memory allocs = _createAllocation(0, 1, 64 ether);
    vm.prank(address(0x1));
    depositManager.depositToConsensusLayerWithDepositRoot(allocs, bytes32(0));
    assert(address(depositManager).balance == 0);
}
```

Note: The test mock `_getNextValidators` at line 42-62 currently ignores `depositAmounts` from allocations, so this test will verify the deposit manager logic but the mock will still return the same keys. The `_depositValidator` function needs to accept the variable amount.

Run: `cd contracts && forge test --match-test testDepositVariableAmount -vvv`
Expected: FAIL (the deposit manager still uses hardcoded DEPOSIT_SIZE)

**Step 2: Update _depositValidator to accept variable amount**

In `contracts/src/components/ConsensusLayerDepositManager.1.sol`, modify `_depositValidator()` at line 159:

```solidity
/// @notice Deposits ETH to the official Deposit contract
/// @param _publicKey The public key of the validator
/// @param _signature The signature provided by the operator
/// @param _withdrawalCredentials The withdrawal credentials provided by River
/// @param _depositAmount The amount of ETH to deposit for this validator
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
    uint256 value = _depositAmount;

    uint256 depositAmount = value / 1 gwei;

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
            sha256(bytes.concat(bytes32(LibUint256.toLittleEndian64(depositAmount)), signatureRoot))
        )
    );

    uint256 targetBalance = address(this).balance - value;

    IDepositContract(DepositContractAddress.get()).deposit{value: value}(
        _publicKey, abi.encodePacked(_withdrawalCredentials), _signature, depositDataRoot
    );
    if (address(this).balance != targetBalance) {
        revert ErrorOnDeposit();
    }
}
```

**Step 3: Update depositToConsensusLayerWithDepositRoot**

Replace the function at lines 94-153 with:

```solidity
/// @inheritdoc IConsensusLayerDepositManagerV1
function depositToConsensusLayerWithDepositRoot(
    IOperatorsRegistryV1.OperatorAllocation[] calldata _allocations,
    bytes32 _depositRoot
) external {
    if (msg.sender != KeeperAddress.get()) {
        revert OnlyKeeper();
    }

    if (IDepositContract(DepositContractAddress.get()).get_deposit_root() != _depositRoot) {
        revert InvalidDepositRoot();
    }

    uint256 committedBalance = CommittedBalance.get();

    // Calculate total requested ETH and validator count from allocations
    uint256 totalRequestedETH = 0;
    uint256 totalRequestedValidators = 0;
    for (uint256 i = 0; i < _allocations.length; ++i) {
        if (_allocations[i].depositAmounts.length != _allocations[i].validatorCount) {
            revert InvalidDepositAmounts();
        }
        for (uint256 j = 0; j < _allocations[i].depositAmounts.length; ++j) {
            totalRequestedETH += _allocations[i].depositAmounts[j];
        }
        totalRequestedValidators += _allocations[i].validatorCount;
    }

    if (totalRequestedETH == 0) {
        revert NotEnoughFunds();
    }

    // Check if the total requested ETH exceeds the committed balance
    if (totalRequestedETH > committedBalance) {
        revert OperatorAllocationsExceedCommittedBalance();
    }

    // it's up to the internal overridden _getNextValidators method to provide two arrays of the same
    // size for the publicKeys and the signatures
    (bytes[] memory publicKeys, bytes[] memory signatures) = _getNextValidators(_allocations);

    uint256 receivedPublicKeyCount = publicKeys.length;

    if (receivedPublicKeyCount == 0) {
        revert NoAvailableValidatorKeys();
    }

    // Check that the received public keys count equals the total requested
    if (receivedPublicKeyCount != totalRequestedValidators) {
        revert InvalidPublicKeyCount();
    }

    bytes32 withdrawalCredentials = WithdrawalCredentials.get();

    if (withdrawalCredentials == 0) {
        revert InvalidWithdrawalCredentials();
    }

    // Flatten deposit amounts to match the flattened public keys array
    uint256 totalDepositedETH = 0;
    uint256 keyIdx = 0;
    for (uint256 i = 0; i < _allocations.length; ++i) {
        for (uint256 j = 0; j < _allocations[i].depositAmounts.length; ++j) {
            _depositValidator(publicKeys[keyIdx], signatures[keyIdx], withdrawalCredentials, _allocations[i].depositAmounts[j]);
            totalDepositedETH += _allocations[i].depositAmounts[j];
            ++keyIdx;
        }
    }

    _setCommittedBalance(committedBalance - totalDepositedETH);
    TotalDepositedETH.set(TotalDepositedETH.get() + totalDepositedETH);
    uint256 currentDepositedValidatorCount = DepositedValidatorCount.get();
    DepositedValidatorCount.set(currentDepositedValidatorCount + receivedPublicKeyCount);
    emit SetDepositedValidatorCount(
        currentDepositedValidatorCount, currentDepositedValidatorCount + receivedPublicKeyCount
    );
}
```

Add the import for TotalDepositedETH at the top of the file (after line 16):

```solidity
import "../state/river/TotalDepositedETH.sol";
```

Add the new error to the interface `contracts/src/interfaces/components/IConsensusLayerDepositManager.1.sol`:

```solidity
/// @notice The deposit amounts array length doesn't match validator count
error InvalidDepositAmounts();
```

**Step 4: Run the test**

Run: `cd contracts && forge test --match-test testDepositVariableAmount -vvv`
Expected: PASS

**Step 5: Run all existing deposit manager tests**

Run: `cd contracts && forge test --match-path test/components/ConsensusLayerDepositManager -vvv`
Expected: All existing tests PASS (they use `_createAllocation` which now defaults to 32 ETH per validator)

**Step 6: Commit**

```bash
git add contracts/src/components/ConsensusLayerDepositManager.1.sol contracts/src/interfaces/components/IConsensusLayerDepositManager.1.sol contracts/test/components/ConsensusLayerDepositManager.1.t.sol
git commit -m "feat: support variable deposit amounts in ConsensusLayerDepositManager"
```

---

### Task 4: Update _assetBalance() in River.1.sol

**Files:**
- Modify: `contracts/src/River.1.sol:1-5` (imports) and `contracts/src/River.1.sol:392-404` (_assetBalance)

**Step 1: Write a failing test for the new formula**

The `_assetBalance()` is an internal function tested via the full River contract. Rather than creating a new test file, the migration initializer test in Task 5 will validate this. For now, focus on the code change.

**Step 2: Add TotalDepositedETH import**

In `contracts/src/River.1.sol`, add after line 30 (the LastConsensusLayerReport import):

```solidity
import "./state/river/TotalDepositedETH.sol";
```

**Step 3: Replace _assetBalance() formula**

Replace lines 392-404 in `contracts/src/River.1.sol`:

```solidity
/// @notice Overridden handler called whenever the total balance of ETH is requested
/// @return The current total asset balance managed by River
function _assetBalance() internal view override(SharesManagerV1, OracleManagerV1) returns (uint256) {
    IOracleManagerV1.StoredConsensusLayerReport storage storedReport = LastConsensusLayerReport.get();
    uint256 totalDeposited = TotalDepositedETH.get();
    uint256 oracleAccountedETH =
        storedReport.validatorsBalance + storedReport.validatorsExitedBalance + storedReport.validatorsSkimmedBalance;
    uint256 baseBalance =
        storedReport.validatorsBalance + BalanceToDeposit.get() + CommittedBalance.get() + BalanceToRedeem.get();
    if (totalDeposited > oracleAccountedETH) {
        return baseBalance + (totalDeposited - oracleAccountedETH);
    } else {
        return baseBalance;
    }
}
```

**Step 4: Verify it compiles**

Run: `cd contracts && forge build`
Expected: Compilation succeeds

**Step 5: Commit**

```bash
git add contracts/src/River.1.sol
git commit -m "feat: replace validator-count-based _assetBalance with ETH-based formula"
```

---

### Task 5: Add Migration Initializer

**Files:**
- Modify: `contracts/src/River.1.sol:118-126` (add new init function after initRiverV1_2)

**Step 1: Add initRiverV1_3**

Insert after line 126 in `contracts/src/River.1.sol` (after `initRiverV1_2`):

```solidity
/// @notice Initializes River V1.3 - migrates to ETH-based accounting
/// @notice Sets TotalDepositedETH such that _assetBalance() is identical before and after upgrade
function initRiverV1_3() external init(3) {
    IOracleManagerV1.StoredConsensusLayerReport storage report = LastConsensusLayerReport.get();
    uint256 totalDepositedETH = (DepositedValidatorCount.get() - report.validatorsCount) * 32 ether
        + report.validatorsBalance + report.validatorsExitedBalance + report.validatorsSkimmedBalance;
    TotalDepositedETH.set(totalDepositedETH);
}
```

Also add the DepositedValidatorCount import if not already present. Check line 13 — `ConsensusLayerDepositManager.1.sol` already imports it transitively, but for clarity add near the other state imports:

```solidity
import "./state/river/DepositedValidatorCount.sol";
```

**Step 2: Write migration equivalence test**

Add a test (in a new test file or existing River test file) that:
1. Sets up a River-like contract with known state (e.g., 10 deposited validators, 8 CL validators, some balances)
2. Computes `_assetBalance()` using the OLD formula
3. Runs `initRiverV1_3()` migration
4. Computes `_assetBalance()` using the NEW formula
5. Asserts they are identical

This test depends heavily on the River test infrastructure. The test should be written to match existing patterns in `contracts/test/River.1.t.sol`.

Run: `cd contracts && forge test --match-test testMigrationEquivalence -vvv`
Expected: PASS

**Step 3: Run all tests**

Run: `cd contracts && forge test`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add contracts/src/River.1.sol contracts/test/
git commit -m "feat: add initRiverV1_3 migration for ETH-based accounting"
```

---

### Task 6: Update OperatorsRegistry to Pass Through Deposit Amounts

**Files:**
- Modify: `contracts/src/OperatorsRegistry.1.sol:418-434` (pickNextValidatorsToDeposit)
- Modify: `contracts/src/OperatorsRegistry.1.sol:535-558` (_getPerOperatorValidatorKeysForAllocations)

The `OperatorsRegistry.pickNextValidatorsToDeposit()` receives allocations from River and returns flattened `(publicKeys[], signatures[])`. The `depositAmounts` field in each allocation is passed through from the keeper's calldata and consumed by `ConsensusLayerDepositManager` — the registry doesn't need to use it, but it does need to accept the struct with the new field.

**Step 1: Verify OperatorsRegistry compiles with the new struct**

Since `OperatorAllocation` is defined in the interface and the registry uses it, the struct change from Task 2 should already propagate. The registry functions that iterate allocations and access `.operatorIndex` and `.validatorCount` don't need changes — they just ignore the new `depositAmounts` field.

Run: `cd contracts && forge build`
Expected: Compilation succeeds

**Step 2: Run OperatorsRegistry tests**

Run: `cd contracts && forge test --match-path test/OperatorsRegistry -vvv`
Expected: All tests PASS (the test helpers from Task 2 already populate `depositAmounts`)

**Step 3: Commit (if any changes were needed)**

```bash
git commit -m "chore: verify OperatorsRegistry works with updated OperatorAllocation"
```

---

### Task 7: Full Integration Test

**Files:**
- Modify: `contracts/test/River.1.t.sol` or create `contracts/test/ETHBasedAccounting.t.sol`

**Step 1: Write integration test for end-to-end variable deposit**

Test the full flow:
1. User deposits ETH via River
2. Keeper triggers `depositToConsensusLayerWithDepositRoot` with variable amounts (e.g., one validator at 64 ETH)
3. Verify `_assetBalance()` correctly reflects the in-flight balance
4. Oracle reports the validator as active
5. Verify `_assetBalance()` correctly adjusts

**Step 2: Write integration test for mixed deposit amounts**

Test a batch deposit with different amounts per validator (e.g., 32 ETH + 64 ETH + 128 ETH = 224 ETH total).

**Step 3: Run all tests**

Run: `cd contracts && forge test`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add contracts/test/
git commit -m "test: add integration tests for ETH-based accounting"
```

---

### Task 8: Clean Up and Final Verification

**Step 1: Run full test suite**

Run: `cd contracts && forge test`
Expected: All tests PASS

**Step 2: Check for any remaining references to DEPOSIT_SIZE in accounting logic**

Search for any code that still multiplies validator count by `DEPOSIT_SIZE` for accounting purposes (not just as a minimum deposit constant). The `DEPOSIT_SIZE` constant itself should remain — it may still be useful as a minimum deposit validation or as a default.

Run: `cd contracts && grep -rn "DEPOSIT_SIZE" src/ --include="*.sol"`
Expected: Only references should be the constant definition and any minimum deposit validation — NOT in `_assetBalance()`.

**Step 3: Commit any cleanup**

```bash
git add -A
git commit -m "chore: clean up remaining validator-count accounting references"
```
