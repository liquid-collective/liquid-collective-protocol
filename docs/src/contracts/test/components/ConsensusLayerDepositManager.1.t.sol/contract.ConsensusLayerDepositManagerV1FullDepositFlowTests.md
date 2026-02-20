# ConsensusLayerDepositManagerV1FullDepositFlowTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ConsensusLayerDepositManager.1.t.sol)

**Inherits:**
[OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md), [BytesGenerator](/contracts/test/utils/BytesGenerator.sol/contract.BytesGenerator.md)

Integration tests for the full deposit flow: Keeper -> DepositManager -> Registry.pickNextValidatorsToDeposit -> DepositContract


## State Variables
### withdrawalCredentials

```solidity
bytes32 internal withdrawalCredentials = bytes32(uint256(1))
```


### keeper

```solidity
address internal keeper = address(0x1)
```


### depositManager

```solidity
ConsensusLayerDepositManagerV1 internal depositManager
```


### registry

```solidity
OperatorsRegistryV1 internal registry
```


### depositContract

```solidity
IDepositContract internal depositContract
```


### admin

```solidity
address internal admin
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testFullDepositFlowSingleOperator

Full flow: single operator, keeper deposits, registry funded and deposited count updated


```solidity
function testFullDepositFlowSingleOperator() public;
```

### testFullDepositFlowSingleOperatorFuzz

Fuzz: full flow single operator with variable key count and deposit amount


```solidity
function testFullDepositFlowSingleOperatorFuzz(uint96 _keyCount, uint96 _toDeposit) public;
```

### testFullDepositFlowMultiOperatorFuzz

Fuzz: full flow two operators with variable key counts and allocation amounts


```solidity
function testFullDepositFlowMultiOperatorFuzz(uint96 _keyCount, uint96 _fromOp0, uint96 _fromOp1) public;
```

### testFullDepositFlowWithInactiveOperatorInMiddle

Full flow: three operators with middle one inactive; allocation only to op0 and op2


```solidity
function testFullDepositFlowWithInactiveOperatorInMiddle() public;
```

### testFullDepositFlowRevertsWhenRegistryRevertsInactiveOperator

Full flow: registry revert (inactive operator) propagates; no state change


```solidity
function testFullDepositFlowRevertsWhenRegistryRevertsInactiveOperator() public;
```

### testFullDepositFlowOnlyKeeperCanDeposit

Only keeper can call depositToConsensusLayerWithDepositRoot


```solidity
function testFullDepositFlowOnlyKeeperCanDeposit() public;
```

### testFullDepositFlowSequentialDeposits

Sequential deposits: first 2 validators, then 3 more from same operator


```solidity
function testFullDepositFlowSequentialDeposits() public;
```

### testUnorderedOperatorListDescendingOperatorIndices


```solidity
function testUnorderedOperatorListDescendingOperatorIndices() public;
```

### testAllocationWithZeroValidatorCount


```solidity
function testAllocationWithZeroValidatorCount() public;
```

### testAllocationWithZeroValidatorCountInMiddle


```solidity
function testAllocationWithZeroValidatorCountInMiddle() public;
```

