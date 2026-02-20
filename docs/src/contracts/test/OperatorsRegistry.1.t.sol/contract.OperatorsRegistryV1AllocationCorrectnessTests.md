# OperatorsRegistryV1AllocationCorrectnessTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/OperatorsRegistry.1.t.sol)

**Inherits:**
[OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md)

**Title:**
Allocation Correctness Tests

Tests that verify the protocol returns the correct keys for the correct operators

when given explicit allocation instructions


## State Variables
### operatorsRegistry

```solidity
OperatorsRegistryV1 internal operatorsRegistry
```


### admin

```solidity
address internal admin
```


### river

```solidity
address internal river
```


### rawKeysByOperator
Per-operator raw key material, stored so we can verify returned keys match


```solidity
bytes[] internal rawKeysByOperator
```


### salt

```solidity
bytes32 salt = bytes32(0)
```


## Functions
### genBytes


```solidity
function genBytes(uint256 len) internal returns (bytes memory);
```

### _extractPublicKey

Extract the public key at a given validator index from the raw key material for an operator


```solidity
function _extractPublicKey(uint256 operatorIdx, uint256 validatorIdx) internal view returns (bytes memory);
```

### _setupOperators

Setup with a configurable number of operators, each with `keysPerOp` keys and limits


```solidity
function _setupOperators(uint256 count, uint32 keysPerOp) internal;
```

### testReturnedKeysMatchCorrectOperators

Verifies that keys returned from a multi-operator allocation actually belong
to the correct operators by comparing against the registered key material.


```solidity
function testReturnedKeysMatchCorrectOperators() external;
```

### testAsymmetricAllocationKeyContent

Allocate heavily uneven counts (1 to op0, 8 to op1, 1 to op2) and verify
each key belongs to the correct operator's registered key set.


```solidity
function testAsymmetricAllocationKeyContent() external;
```

### testLargeOperatorSetSparseAllocation

15 operators registered, only 3 receive allocations. Verifies that the linear
search in _updateCountOfPickedValidatorsForEachOperator correctly finds operators
deep in the array and that non-allocated operators remain unfunded.


```solidity
function testLargeOperatorSetSparseAllocation() external;
```

### testNonContiguousAllocationSkipsActiveOperators

All 5 operators are active and fundable, but allocation only targets op0 and op4.
Verifies that ops 1,2,3 remain at funded=0 despite being active.


```solidity
function testNonContiguousAllocationSkipsActiveOperators() external;
```

### testSequentialAllocationsReturnCorrectKeyOffsets

Two sequential allocations to the same operator. The second allocation must
return keys starting from where the first left off (funded offset).


```solidity
function testSequentialAllocationsReturnCorrectKeyOffsets() external;
```

### testEntireAllocationToSingleOperatorAmongMany

With multiple active operators, allocate everything to just one.
Verifies the others are untouched and the keys are correct.


```solidity
function testEntireAllocationToSingleOperatorAmongMany() external;
```

### testFundedValidatorKeysEventContentForAsymmetricAllocation

Verifies the FundedValidatorKeys events emitted during allocation carry the
correct operator index and the correct key bytes for an asymmetric allocation.


```solidity
function testFundedValidatorKeysEventContentForAsymmetricAllocation() external;
```

### testOperatorHasInsufficientFundableKeysWithPartialFunding

Tests OperatorHasInsufficientFundableKeys when some keys are already funded
This covers the case where availableKeys = limit - (funded + picked) is less than requested


```solidity
function testOperatorHasInsufficientFundableKeysWithPartialFunding() public;
```

### testPickNextValidatorsEmitsFundedValidatorKeysEvent

Tests that pickNextValidatorsToDeposit correctly updates funded count and emits FundedValidatorKeys


```solidity
function testPickNextValidatorsEmitsFundedValidatorKeysEvent() public;
```

### testMultiOperatorAllocationKeyOrdering

Tests multi-operator allocation with correct key ordering


```solidity
function testMultiOperatorAllocationKeyOrdering() public;
```

### testSequentialAllocationsToSameOperator

Tests that sequential allocations to the same operator work correctly


```solidity
function testSequentialAllocationsToSameOperator() public;
```

### testViewVsStateModifyingBehavior

Tests that getNextValidators (view) doesn't modify state while pickNextValidators does


```solidity
function testViewVsStateModifyingBehavior() public;
```

## Events
### FundedValidatorKeys

```solidity
event FundedValidatorKeys(uint256 indexed index, bytes[] publicKeys, bool deferred);
```

