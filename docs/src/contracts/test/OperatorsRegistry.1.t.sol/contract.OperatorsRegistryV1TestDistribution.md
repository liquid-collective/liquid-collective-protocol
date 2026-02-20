# OperatorsRegistryV1TestDistribution
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/OperatorsRegistry.1.t.sol)

**Inherits:**
[OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md)


## State Variables
### uf

```solidity
UserFactory internal uf = new UserFactory()
```


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


### firstName

```solidity
string internal firstName = "Operator One"
```


### secondName

```solidity
string internal secondName = "Operator Two"
```


### operatorOne

```solidity
address internal operatorOne
```


### operatorTwo

```solidity
address internal operatorTwo
```


### operatorThree

```solidity
address internal operatorThree
```


### operatorFour

```solidity
address internal operatorFour
```


### operatorFive

```solidity
address internal operatorFive
```


### keeper

```solidity
address internal keeper
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

### setUp


```solidity
function setUp() public;
```

### testPickNextValidatorsToDepositSucceedsWithInactiveOperatorInMiddle

Multiple active operators with an inactive operator in the middle; allocation only to active ops

Allocation [op0, op2] with op1 inactive must succeed and return keys from op0 and op2 only


```solidity
function testPickNextValidatorsToDepositSucceedsWithInactiveOperatorInMiddle() public;
```

### testPickNextValidatorsToDepositRevertsWhenAllAllocationsAreToInactiveOperators

Allocation only to inactive operators reverts with InactiveOperator


```solidity
function testPickNextValidatorsToDepositRevertsWhenAllAllocationsAreToInactiveOperators() public;
```

### testPickNextValidatorsToDepositRevertsWhenAllAllocationsAreToNonFundableOperators

Allocation only to non-fundable operators (limit already reached) reverts


```solidity
function testPickNextValidatorsToDepositRevertsWhenAllAllocationsAreToNonFundableOperators() public;
```

### testPickNextValidatorsToDepositRevertsWhenSecondOperatorInAllocationIsInactive

Multi-operator allocation with second operator inactive reverts on that entry


```solidity
function testPickNextValidatorsToDepositRevertsWhenSecondOperatorInAllocationIsInactive() public;
```

### testPickNextValidatorsToDepositRevertsWhenOperatorHasLimitZero

Allocation to operator with limit zero has no fundable keys


```solidity
function testPickNextValidatorsToDepositRevertsWhenOperatorHasLimitZero() public;
```

### _bytesToPublicKeysArray


```solidity
function _bytesToPublicKeysArray(bytes memory raw, uint256 start, uint256 end)
    internal
    pure
    returns (bytes[] memory res);
```

### testRegularDepositDistribution


```solidity
function testRegularDepositDistribution() external;
```

### testDepositDistributionWithZeroCountAllocationFails


```solidity
function testDepositDistributionWithZeroCountAllocationFails() external;
```

### testInactiveDepositDistribution


```solidity
function testInactiveDepositDistribution() external;
```

### testStoppedDepositDistribution


```solidity
function testStoppedDepositDistribution() external;
```

### testDepositDistributionWithOperatorsWithPositiveStoppedDelta


```solidity
function testDepositDistributionWithOperatorsWithPositiveStoppedDelta() external;
```

### testNonKeeperCantRequestExits


```solidity
function testNonKeeperCantRequestExits() external;
```

### testRequestValidatorNoExits


```solidity
function testRequestValidatorNoExits() external;
```

### testRequestExitsWithInactiveOperator


```solidity
function testRequestExitsWithInactiveOperator() external;
```

### testRequestExitsWithMoreRequestsThanDemand


```solidity
function testRequestExitsWithMoreRequestsThanDemand() external;
```

### testRequestExitsRequestedExceedDemand


```solidity
function testRequestExitsRequestedExceedDemand() external;
```

### testRequestExitsWithUnorderedOperators


```solidity
function testRequestExitsWithUnorderedOperators() external;
```

### testRequestExitsWithInvalidEmptyArray


```solidity
function testRequestExitsWithInvalidEmptyArray() external;
```

### testRequestExitsWithAllocationWithZeroValidatorCount


```solidity
function testRequestExitsWithAllocationWithZeroValidatorCount() external;
```

### testRegularExitDistribution


```solidity
function testRegularExitDistribution() external;
```

### testExitDistributionUnevenFunded


```solidity
function testExitDistributionUnevenFunded() external;
```

### testExitDistributionWithUnsollicitedExits


```solidity
function testExitDistributionWithUnsollicitedExits() external;
```

### testOneExitDistribution


```solidity
function testOneExitDistribution() external;
```

### testNonOverlappingSuccessiveExitRequests

Two successive exit rounds with non-overlapping operator sets verify independence


```solidity
function testNonOverlappingSuccessiveExitRequests() external;
```

### testExitRequestExactlyMatchesDemand

Exit request that exactly matches the current demand (boundary: requestedExitCount == currentValidatorExitsDemand)


```solidity
function testExitRequestExactlyMatchesDemand() external;
```

### testUnevenExitDistribution


```solidity
function testUnevenExitDistribution() external;
```

### testDecreasingStoppedValidatorCounts


```solidity
function testDecreasingStoppedValidatorCounts(uint8 decreasingIndex, uint8[5] memory fuzzedStoppedValidatorCount)
    external;
```

### testStoppedValidatorCountAboveFundedCount


```solidity
function testStoppedValidatorCountAboveFundedCount(
    uint8 decreasingIndex,
    uint8[5] memory fuzzedStoppedValidatorCount
) external;
```

### testStoppedValidatorCountArrayShrinking


```solidity
function testStoppedValidatorCountArrayShrinking(uint8[5] memory fuzzedStoppedValidatorCount) external;
```

### testStoppedValidatorCountAboveFundedCountOnNewArrayElements


```solidity
function testStoppedValidatorCountAboveFundedCountOnNewArrayElements(uint8[5] memory fuzzedStoppedValidatorCount)
    external;
```

### testDecreasingStoppedValidatorCountsSum


```solidity
function testDecreasingStoppedValidatorCountsSum(uint16[5] memory fuzzedStoppedValidatorCount) external;
```

### testStoppedValidatorCountHigherThanDepositCount


```solidity
function testStoppedValidatorCountHigherThanDepositCount() external;
```

### testSetOperatorLimitsFail


```solidity
function testSetOperatorLimitsFail() public;
```

### testGetNextValidatorsToDepositFromActiveOperators


```solidity
function testGetNextValidatorsToDepositFromActiveOperators() public;
```

### testGetNextValidatorsToDepositRevertsWhenExceedingLimit


```solidity
function testGetNextValidatorsToDepositRevertsWhenExceedingLimit() public;
```

### testPickNextValidatorsToDepositRevertsInactiveOperator


```solidity
function testPickNextValidatorsToDepositRevertsInactiveOperator() public;
```

### testPickNextValidatorsToDepositRevertsInactiveOperatorWithMultipleFundableOperators


```solidity
function testPickNextValidatorsToDepositRevertsInactiveOperatorWithMultipleFundableOperators() public;
```

### testPickNextValidatorsToDepositRevertsWhenExceedingLimit


```solidity
function testPickNextValidatorsToDepositRevertsWhenExceedingLimit() public;
```

### testGetNextValidatorsToDepositRevertsWithInactiveOperator


```solidity
function testGetNextValidatorsToDepositRevertsWithInactiveOperator() public;
```

### testPickNextValidatorsToDepositRevertsWithInactiveOperator


```solidity
function testPickNextValidatorsToDepositRevertsWithInactiveOperator() public;
```

### testGetNextValidatorsToDepositRevertsDuplicateOperatorIndex


```solidity
function testGetNextValidatorsToDepositRevertsDuplicateOperatorIndex() public;
```

### testGetNextValidatorsToDepositRevertsUnorderedOperatorIndex


```solidity
function testGetNextValidatorsToDepositRevertsUnorderedOperatorIndex() public;
```

### testPickNextValidatorsToDepositRevertsDuplicateOperatorIndex


```solidity
function testPickNextValidatorsToDepositRevertsDuplicateOperatorIndex() public;
```

### testPickNextValidatorsToDepositRevertsUnorderedOperatorIndex


```solidity
function testPickNextValidatorsToDepositRevertsUnorderedOperatorIndex() public;
```

### testGetNextValidatorsToDepositRevertsZeroValidatorCount


```solidity
function testGetNextValidatorsToDepositRevertsZeroValidatorCount() public;
```

### testPickNextValidatorsToDepositRevertsZeroValidatorCount


```solidity
function testPickNextValidatorsToDepositRevertsZeroValidatorCount() public;
```

### testGetNextValidatorsToDepositRevertsInactiveOperator


```solidity
function testGetNextValidatorsToDepositRevertsInactiveOperator() public;
```

### testGetNextValidatorsToDepositRevertsWithOperatorNotFound


```solidity
function testGetNextValidatorsToDepositRevertsWithOperatorNotFound() public;
```

### testPickNextValidatorsToDepositRevertsWithOperatorNotFound


```solidity
function testPickNextValidatorsToDepositRevertsWithOperatorNotFound() public;
```

### testPickNextValidatorsToDepositRevertsUnkonwnOperatorWithMultipleFundableOperators


```solidity
function testPickNextValidatorsToDepositRevertsUnkonwnOperatorWithMultipleFundableOperators() public;
```

### testVersion


```solidity
function testVersion() external;
```

### testGetNextValidatorsToDepositFromActiveOperatorsRevertsWithEmptyAllocation


```solidity
function testGetNextValidatorsToDepositFromActiveOperatorsRevertsWithEmptyAllocation() public;
```

### testGetNextValidatorsToDepositRevertsOperatorIgnoredExitRequests

Tests OperatorIgnoredExitRequests when getNextValidatorsToDepositFromActiveOperators is called
for an operator that has requested exits but has not yet had enough validators reported as stopped


```solidity
function testGetNextValidatorsToDepositRevertsOperatorIgnoredExitRequests() public;
```

### testPickNextValidatorsToDepositRevertsOperatorIgnoredExitRequests

Tests OperatorIgnoredExitRequests when pickNextValidatorsToDeposit is called
for an operator that has requested exits but has not yet had enough validators reported as stopped


```solidity
function testPickNextValidatorsToDepositRevertsOperatorIgnoredExitRequests() public;
```

### testOperatorIgnoredExitRequestsWhenStoppedCountBelowRequested

Tests OperatorIgnoredExitRequests when stopped validator count is reported but below requested exits


```solidity
function testOperatorIgnoredExitRequestsWhenStoppedCountBelowRequested() public;
```

### testOperatorHasInsufficientFundableKeysWithPartialFunding

Tests OperatorHasInsufficientFundableKeys when some keys are already funded
This covers the case where availableKeys = limit - funded is less than requested


```solidity
function testOperatorHasInsufficientFundableKeysWithPartialFunding() public;
```

### testInactiveOperatorWhenOperatorExistsButDeactivated

Tests InactiveOperator error when operator exists but has been deactivated
This is different from non-existent operator - the operator exists but is inactive


```solidity
function testInactiveOperatorWhenOperatorExistsButDeactivated() public;
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

### testMultiOperatorCombinedKeysOrderMatchesAllocationsArray

Tests that combined validator keys from multi-operator allocation match allocations[] order
(first all keys for allocations[0].operatorIndex, then all for allocations[1], etc.)


```solidity
function testMultiOperatorCombinedKeysOrderMatchesAllocationsArray() public;
```

### testSequentialAllocationsToSameOperator

Tests that sequential allocations to the same operator work correctly


```solidity
function testSequentialAllocationsToSameOperator() public;
```

### testAllocationWhenOperatorFullyFunded

Tests allocation when operator has no available keys (limit == funded)


```solidity
function testAllocationWhenOperatorFullyFunded() public;
```

### testViewVsStateModifyingBehavior

Tests that getNextValidators (view) doesn't modify state while pickNextValidators does


```solidity
function testViewVsStateModifyingBehavior() public;
```

### testFundedCountPersistsInStorageAndIsUsedOnNextCall

Tests that the funded count updated in pickNextValidatorsToDeposit is a storage update:
it persists beyond the transaction and the next read (or next pick) sees the higher value.


```solidity
function testFundedCountPersistsInStorageAndIsUsedOnNextCall() public;
```

### testMultiOperatorWithPartialFunding

Tests allocation with multiple operators where one has partially funded keys


```solidity
function testMultiOperatorWithPartialFunding() public;
```

### testMultiOperatorSecondOperatorExceedsLimit

Tests that pick reverts with OperatorHasInsufficientFundableKeys for second operator in multi-allocation


```solidity
function testMultiOperatorSecondOperatorExceedsLimit() public;
```

### testPickNextValidatorsToDepositReturnsEmptyAllocation

Tests reverts with InvalidEmptyArray when allocation is empty


```solidity
function testPickNextValidatorsToDepositReturnsEmptyAllocation() public;
```

## Events
### AddedValidatorKeys

```solidity
event AddedValidatorKeys(uint256 indexed index, bytes publicKeys);
```

### RemovedValidatorKey

```solidity
event RemovedValidatorKey(uint256 indexed index, bytes publicKey);
```

### RequestedValidatorExits

```solidity
event RequestedValidatorExits(uint256 indexed index, uint256 count);
```

### FundedValidatorKeys

```solidity
event FundedValidatorKeys(uint256 indexed index, bytes[] publicKeys, bool deferred);
```

### SetTotalValidatorExitsRequested

```solidity
event SetTotalValidatorExitsRequested(uint256 previousTotalRequestedExits, uint256 newTotalRequestedExits);
```

### UpdatedRequestedValidatorExitsUponStopped

```solidity
event UpdatedRequestedValidatorExitsUponStopped(
    uint256 indexed index, uint32 oldRequestedExits, uint32 newRequestedExits
);
```

### SetCurrentValidatorExitsDemand

```solidity
event SetCurrentValidatorExitsDemand(uint256 previousValidatorExitsDemand, uint256 nextValidatorExitsDemand);
```

