# LastEpochId
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/oracle/LastEpochId.sol)

**Title:**
Last Epoch Id Storage

Utility to manage the Last Epoch Id in storage


## State Variables
### LAST_EPOCH_ID_SLOT
Storage slot of the Last Epoch Id


```solidity
bytes32 internal constant LAST_EPOCH_ID_SLOT = bytes32(uint256(keccak256("river.state.lastEpochId")) - 1)
```


## Functions
### get

Retrieve the Last Epoch Id


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Last Epoch Id|


### set

Sets the Last Epoch Id


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New Last Epoch Id|


