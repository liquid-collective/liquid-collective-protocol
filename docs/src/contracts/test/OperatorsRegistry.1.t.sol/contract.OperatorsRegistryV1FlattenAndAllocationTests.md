# OperatorsRegistryV1FlattenAndAllocationTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/OperatorsRegistry.1.t.sol)

**Inherits:**
[OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md)

Tests that exercise _flattenByteArrays and allocation validation logic
via the public view function getNextValidatorsToDepositFromActiveOperators.


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

### _extractSignature

Extract the signature at a given validator index from the raw key material for an operator


```solidity
function _extractSignature(uint256 operatorIdx, uint256 validatorIdx) internal view returns (bytes memory);
```

### _setupOperators

Setup with a configurable number of operators, each with `keysPerOp` keys and limits


```solidity
function _setupOperators(uint256 count, uint32 keysPerOp) internal;
```

### testFlattenSingleOperatorSingleKey

1 operator, allocate 1 key. Verify returned arrays have length 1 and key matches.


```solidity
function testFlattenSingleOperatorSingleKey() external;
```

### testFlattenSingleOperatorAllKeys

1 operator with 10 keys, allocate all 10. Verify returned array length == 10 and all keys match.


```solidity
function testFlattenSingleOperatorAllKeys() external;
```

### testFlattenMultiOperatorVerifyOrder

3 operators, allocate [2, 3, 1]. Verify 6 returned keys are in correct
operator order (op0 keys first, then op1, then op2) with correct content.


```solidity
function testFlattenMultiOperatorVerifyOrder() external;
```

### testFlattenSignaturesMatchKeys

2 operators, allocate [2, 2]. Verify both publicKeys and signatures arrays
have length 4 and each signature corresponds to the correct key's registered signature.


```solidity
function testFlattenSignaturesMatchKeys() external;
```

### testGetNextValidatorsRevertsEmptyAllocation

Pass empty OperatorAllocation[] to getNextValidatorsToDepositFromActiveOperators. Expect InvalidEmptyArray().


```solidity
function testGetNextValidatorsRevertsEmptyAllocation() external;
```

### testGetNextValidatorsRevertsUnorderedList

Pass allocations with descending operator indices. Expect UnorderedOperatorList().


```solidity
function testGetNextValidatorsRevertsUnorderedList() external;
```

### testGetNextValidatorsRevertsZeroValidatorCount

Pass allocation with validatorCount: 0. Expect AllocationWithZeroValidatorCount().


```solidity
function testGetNextValidatorsRevertsZeroValidatorCount() external;
```

### testGetNextValidatorsRevertsOperatorIgnoredExitRequests

Set up an operator with requestedExits > stoppedCount, then try to get validators.
Expect OperatorIgnoredExitRequests().


```solidity
function testGetNextValidatorsRevertsOperatorIgnoredExitRequests() external;
```

### testGetNextValidatorsRevertsInsufficientFundableKeys

Allocate more keys than available (limit - funded). Expect OperatorHasInsufficientFundableKeys().


```solidity
function testGetNextValidatorsRevertsInsufficientFundableKeys() external;
```

