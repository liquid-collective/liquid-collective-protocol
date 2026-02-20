# ConsensusLayerDepositManagerV1AllocationValidationTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ConsensusLayerDepositManager.1.t.sol)

**Inherits:**
[OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md), [BytesGenerator](/contracts/test/utils/BytesGenerator.sol/contract.BytesGenerator.md)

Tests allocation validation (UnorderedOperatorList, AllocationWithZeroValidatorCount) via real OperatorsRegistry flow


## State Variables
### withdrawalCredentials

```solidity
bytes32 internal withdrawalCredentials = bytes32(uint256(1))
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

### testUnorderedOperatorListDuplicate


```solidity
function testUnorderedOperatorListDuplicate() public;
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

