# OperatorsV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/operatorsRegistry/Operators.1.sol)

**Title:**
Operators Storage

Utility to manage the Operators in storage

This state variable is deprecated and was kept due to migration logic needs


## State Variables
### OPERATORS_SLOT
Storage slot of the Operators


```solidity
bytes32 internal constant OPERATORS_SLOT = bytes32(uint256(keccak256("river.state.operators")) - 1)
```


## Functions
### get

Retrieve the operator in storage


```solidity
function get(uint256 _index) internal view returns (Operator storage);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The index of the operator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Operator`|The Operator structure|


### getCount

Retrieve the operator count in storage


```solidity
function getCount() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The count of operators in storage|


### getAllActive

Retrieve all the active operators


```solidity
function getAllActive() internal view returns (Operator[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Operator[]`|The list of active operator structures|


### getAllFundable

Retrieve all the active and fundable operators


```solidity
function getAllFundable() internal view returns (CachedOperator[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CachedOperator[]`|The list of active and fundable operators|


### push

Add a new operator in storage


```solidity
function push(Operator memory _newOperator) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newOperator`|`Operator`|Value of the new operator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The size of the operator array after the operation|


### setKeys

Atomic operation to set the key count and update the latestKeysEditBlockNumber field at the same time


```solidity
function setKeys(uint256 _index, uint256 _newKeys) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The operator index|
|`_newKeys`|`uint256`|The new value for the key count|


### _hasFundableKeys

Checks if an operator is active and has fundable keys


```solidity
function _hasFundableKeys(OperatorsV1.Operator memory _operator) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`OperatorsV1.Operator`|The operator details|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if active and fundable|


## Errors
### OperatorNotFound
The operator was not found


```solidity
error OperatorNotFound(uint256 index);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The provided index|

## Structs
### Operator
The Operator structure in storage


```solidity
struct Operator {
    /// @custom:attribute True if the operator is active and allowed to operate on River
    bool active;
    /// @custom:attribute Display name of the operator
    string name;
    /// @custom:attribute Address of the operator
    address operator;
    /// @dev The following values respect this invariant:
    /// @dev     keys >= limit >= funded >= stopped

    /// @custom:attribute Staking limit of the operator
    uint256 limit;
    /// @custom:attribute The count of funded validators
    uint256 funded;
    /// @custom:attribute The total count of keys of the operator
    uint256 keys;
    /// @custom:attribute The count of stopped validators. Stopped validators are validators
    ///                   that exited the consensus layer (voluntary or slashed)
    uint256 stopped;
    uint256 latestKeysEditBlockNumber;
}
```

### CachedOperator
The Operator structure when loaded in memory


```solidity
struct CachedOperator {
    /// @custom:attribute True if the operator is active and allowed to operate on River
    bool active;
    /// @custom:attribute Display name of the operator
    string name;
    /// @custom:attribute Address of the operator
    address operator;
    /// @custom:attribute Staking limit of the operator
    uint256 limit;
    /// @custom:attribute The count of funded validators
    uint256 funded;
    /// @custom:attribute The total count of keys of the operator
    uint256 keys;
    /// @custom:attribute The count of stopped validators
    uint256 stopped;
    /// @custom:attribute The count of stopped validators. Stopped validators are validators
    ///                   that exited the consensus layer (voluntary or slashed)
    uint256 index;
    /// @custom:attribute The amount of picked keys, buffer used before changing funded in storage
    uint256 picked;
}
```

### SlotOperator
The structure at the storage slot


```solidity
struct SlotOperator {
    /// @custom:attribute Array containing all the operators
    Operator[] value;
}
```

