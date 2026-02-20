# Version
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/shared/Version.sol)

**Title:**
Version Storage

Utility to manage the Version in storage


## State Variables
### VERSION_SLOT
Storage slot of the Version


```solidity
bytes32 public constant VERSION_SLOT = bytes32(uint256(keccak256("river.state.version")) - 1)
```


## Functions
### get

Retrieve the Version


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Version|


### set

Sets the Version


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New Version|


