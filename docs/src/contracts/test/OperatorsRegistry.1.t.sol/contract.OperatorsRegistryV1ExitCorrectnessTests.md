# OperatorsRegistryV1ExitCorrectnessTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/OperatorsRegistry.1.t.sol)

**Inherits:**
[OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md)

**Title:**
Exit Allocation Correctness Tests

Tests that verify the exit allocation logic correctly tracks per-operator
requestedExits across sequential calls, partial fulfillment, stopped validator
interactions, and combined deposit+exit flows.


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

### _fundAllOperators

Fund all 5 operators with 50 validators each and set limits


```solidity
function _fundAllOperators() internal;
```

### testSequentialExitAllocationsAccumulate

Two rounds of exits to overlapping operators. Verifies requestedExits
accumulates correctly and demand decrements across both calls.


```solidity
function testSequentialExitAllocationsAccumulate() external;
```

### testNonContiguousExitAllocations

Exit from operators 0 and 4 only, skipping active operators 1,2,3.
Verifies skipped operators remain at requestedExits=0.


```solidity
function testNonContiguousExitAllocations() external;
```

### testPartialDemandFulfillmentAcrossMultipleCalls

Demand is 100. Keeper fulfills 40 in first call, then 60 in second call.
Verifies demand decrements correctly and total accumulates.


```solidity
function testPartialDemandFulfillmentAcrossMultipleCalls() external;
```

### testStoppedValidatorsAndExitsMultiStep

Multi-step: demand exits -> stop some validators (reducing demand) -> exit some
-> stop more -> exit more. Verifies demand and requestedExits track correctly
through the interleaved sequence.


```solidity
function testStoppedValidatorsAndExitsMultiStep() external;
```

### testDepositThenExitEndToEnd

Combined flow: deposit validators via BYOV allocation, then exit some,
then simulate validators stopping, then deposit more.
Verifies funded and requestedExits are both correct throughout.
Key invariant: getAllFundable() requires stoppedCount >= requestedExits
for an operator to be eligible for new deposits. This means you can't
deposit to an operator with pending (unfulfilled) exit requests until
those validators have actually stopped.


```solidity
function testDepositThenExitEndToEnd() external;
```

### testExitsRequestedExceedDemandByOne

Demand is 10. Request exactly 11 exits (1 over). Verify the exact error parameters.


```solidity
function testExitsRequestedExceedDemandByOne() external;
```

### testExitsRequestedExceedDemandAfterPartialFulfillment

Demand is 20. First call fulfills 15. Second call tries to exit 10 (5 over remaining 5).


```solidity
function testExitsRequestedExceedDemandAfterPartialFulfillment() external;
```

### testExitsRequestedExactlyMatchesDemand

Demand is 10, request exactly 10 across multiple operators. Verify it succeeds and demand goes to 0.


```solidity
function testExitsRequestedExactlyMatchesDemand() external;
```

### testStoppedCountExceedingRequestedExitsBumpsRequestedExits

When stopped validator count exceeds an operator's requestedExits,
requestedExits is bumped to match the stopped count, the unsolicited
delta is added to TotalValidatorExitsRequested, and
CurrentValidatorExitsDemand is reduced by the unsolicited amount.
This test exercises the FIRST loop in _setStoppedValidatorCounts
(existing operators path) by making two successive stopped-count reports.


```solidity
function testStoppedCountExceedingRequestedExitsBumpsRequestedExits() external;
```

### testStoppedCountExceedingRequestedExitsClampsDemandToZero

When stopped count exceeds requestedExits and the unsolicited amount
is larger than the remaining demand, demand is clamped to zero.


```solidity
function testStoppedCountExceedingRequestedExitsClampsDemandToZero() external;
```

### testStoppedCountExceedingRequestedExitsForNewOperator

When a new operator is added between two stopped-count reports,
the second report includes the new operator's stopped count which
triggers the requestedExits bump in the "new operator" loop.


```solidity
function testStoppedCountExceedingRequestedExitsForNewOperator() external;
```

## Events
### RequestedValidatorExits

```solidity
event RequestedValidatorExits(uint256 indexed index, uint256 count);
```

### SetTotalValidatorExitsRequested

```solidity
event SetTotalValidatorExitsRequested(uint256 previousTotalRequestedExits, uint256 newTotalRequestedExits);
```

### SetCurrentValidatorExitsDemand

```solidity
event SetCurrentValidatorExitsDemand(uint256 previousValidatorExitsDemand, uint256 nextValidatorExitsDemand);
```

### UpdatedRequestedValidatorExitsUponStopped

```solidity
event UpdatedRequestedValidatorExitsUponStopped(
    uint256 indexed index, uint32 oldRequestedExits, uint32 newRequestedExits
);
```

### UpdatedStoppedValidators

```solidity
event UpdatedStoppedValidators(uint32[] stoppedValidatorCounts);
```

