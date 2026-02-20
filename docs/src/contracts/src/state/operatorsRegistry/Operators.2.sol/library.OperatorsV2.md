# OperatorsV2
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/operatorsRegistry/Operators.2.sol)

**Title:**
Operators Storage

Utility to manage the Operators in storage


## State Variables
### OPERATORS_SLOT
Storage slot of the Operators


```solidity
bytes32 internal constant OPERATORS_SLOT = bytes32(uint256(keccak256("river.state.v2.operators")) - 1)
```


### STOPPED_VALIDATORS_SLOT
Storage slot of the Stopped Validators


```solidity
bytes32 internal constant STOPPED_VALIDATORS_SLOT =
    bytes32(uint256(keccak256("river.state.stoppedValidators")) - 1)
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


### getAll

Retrieve the operators in storage


```solidity
function getAll() internal view returns (Operator[] storage);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Operator[]`|The Operator structure array|


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


### _getStoppedValidatorCountAtIndex

Retrieve the stopped validator count for an operator by its index


```solidity
function _getStoppedValidatorCountAtIndex(uint32[] storage stoppedValidatorCounts, uint256 index)
    internal
    view
    returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stoppedValidatorCounts`|`uint32[]`|The storage pointer to the raw array containing the stopped validator counts|
|`index`|`uint256`|The index of the operator to lookup|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The amount of stopped validators for the given operator index|


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
function setKeys(uint256 _index, uint32 _newKeys) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The operator index|
|`_newKeys`|`uint32`|The new value for the key count|


### getStoppedValidators

Retrieve the storage pointer of the Stopped Validators array


```solidity
function getStoppedValidators() internal view returns (uint32[] storage);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32[]`|The Stopped Validators storage pointer|


### setRawStoppedValidators

Sets the entire stopped validators array


```solidity
function setRawStoppedValidators(uint32[] memory value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint32[]`|The new stopped validators array|


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
    /// @dev The following values respect this invariant:
    /// @dev     keys >= limit >= funded >= RequestedExits

    /// @custom:attribute Staking limit of the operator
    uint32 limit;
    /// @custom:attribute The count of funded validators
    uint32 funded;
    /// @custom:attribute The count of exit requests made to this operator
    uint32 requestedExits;
    /// @custom:attribute The total count of keys of the operator
    uint32 keys;
    /// @custom:attribute The block at which the last edit happened in the operator details
    uint64 latestKeysEditBlockNumber;
    /// @custom:attribute True if the operator is active and allowed to operate on River
    bool active;
    /// @custom:attribute Display name of the operator
    string name;
    /// @custom:attribute Address of the operator
    address operator;
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

### SlotStoppedValidators

```solidity
struct SlotStoppedValidators {
    uint32[] value;
}
```

