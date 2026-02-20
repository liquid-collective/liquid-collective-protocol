# OperatorsV1Harness
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/state/operatorsRegistry/Operators.1.t.sol)

**Title:**
Harness contract to expose internal OperatorsV1 library functions


## Functions
### push

Push a new operator


```solidity
function push(OperatorsV1.Operator memory _operator) external returns (uint256);
```

### get

Get an operator by index


```solidity
function get(uint256 _index) external view returns (OperatorsV1.Operator memory);
```

### getCount

Get the count of operators


```solidity
function getCount() external view returns (uint256);
```

### getAllActive

Get all active operators


```solidity
function getAllActive() external view returns (OperatorsV1.Operator[] memory);
```

### getAllFundable

Get all fundable operators


```solidity
function getAllFundable() external view returns (OperatorsV1.CachedOperator[] memory);
```

### setKeys

Set keys for an operator


```solidity
function setKeys(uint256 _index, uint256 _newKeys) external;
```

### hasFundableKeys

Check if operator has fundable keys


```solidity
function hasFundableKeys(OperatorsV1.Operator memory _operator) external pure returns (bool);
```

### setOperatorActive

Helper to set operator fields for testing


```solidity
function setOperatorActive(uint256 _index, bool _active) external;
```

### setOperatorLimit

Helper to set operator limit for testing


```solidity
function setOperatorLimit(uint256 _index, uint256 _limit) external;
```

### setOperatorFunded

Helper to set operator funded for testing


```solidity
function setOperatorFunded(uint256 _index, uint256 _funded) external;
```

