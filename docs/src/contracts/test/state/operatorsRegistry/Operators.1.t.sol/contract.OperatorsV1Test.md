# OperatorsV1Test
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/state/operatorsRegistry/Operators.1.t.sol)

**Inherits:**
Test


## State Variables
### harness

```solidity
OperatorsV1Harness internal harness
```


## Functions
### setUp


```solidity
function setUp() public;
```

### _createOperator

Helper to create a valid operator


```solidity
function _createOperator(string memory _name, address _addr, bool _active)
    internal
    pure
    returns (OperatorsV1.Operator memory);
```

### testPushOperator


```solidity
function testPushOperator() public;
```

### testPushMultipleOperators


```solidity
function testPushMultipleOperators() public;
```

### testPushOperatorZeroAddressReverts


```solidity
function testPushOperatorZeroAddressReverts() public;
```

### testPushOperatorEmptyNameReverts


```solidity
function testPushOperatorEmptyNameReverts() public;
```

### testGetOperator


```solidity
function testGetOperator() public;
```

### testGetOperatorNotFoundReverts


```solidity
function testGetOperatorNotFoundReverts() public;
```

### testGetOperatorOutOfBoundsReverts


```solidity
function testGetOperatorOutOfBoundsReverts() public;
```

### testGetCountEmpty


```solidity
function testGetCountEmpty() public;
```

### testGetCountAfterPush


```solidity
function testGetCountAfterPush() public;
```

### testGetAllActiveEmpty


```solidity
function testGetAllActiveEmpty() public;
```

### testGetAllActiveAllActive


```solidity
function testGetAllActiveAllActive() public;
```

### testGetAllActiveWithInactive


```solidity
function testGetAllActiveWithInactive() public;
```

### testGetAllActiveNoneActive


```solidity
function testGetAllActiveNoneActive() public;
```

### testGetAllFundableEmpty


```solidity
function testGetAllFundableEmpty() public;
```

### testGetAllFundableWithFundableOperator


```solidity
function testGetAllFundableWithFundableOperator() public;
```

### testGetAllFundableNotFundableWhenLimitEqualsFunded


```solidity
function testGetAllFundableNotFundableWhenLimitEqualsFunded() public;
```

### testGetAllFundableNotFundableWhenInactive


```solidity
function testGetAllFundableNotFundableWhenInactive() public;
```

### testGetAllFundableMixed


```solidity
function testGetAllFundableMixed() public;
```

### testSetKeys


```solidity
function testSetKeys() public;
```

### testSetKeysUpdatesBlockNumber


```solidity
function testSetKeysUpdatesBlockNumber() public;
```

### testSetKeysOperatorNotFoundReverts


```solidity
function testSetKeysOperatorNotFoundReverts() public;
```

### testHasFundableKeysActiveWithAvailableKeys


```solidity
function testHasFundableKeysActiveWithAvailableKeys() public;
```

### testHasFundableKeysInactive


```solidity
function testHasFundableKeysInactive() public;
```

### testHasFundableKeysLimitEqualsFunded


```solidity
function testHasFundableKeysLimitEqualsFunded() public;
```

### testHasFundableKeysZeroLimit


```solidity
function testHasFundableKeysZeroLimit() public;
```

