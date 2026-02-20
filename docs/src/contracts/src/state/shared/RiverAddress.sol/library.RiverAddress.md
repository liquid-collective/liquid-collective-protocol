# RiverAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/shared/RiverAddress.sol)

**Title:**
River Address Storage

Utility to manage the River Address in storage


## State Variables
### RIVER_ADDRESS_SLOT
Storage slot of the River Address


```solidity
bytes32 internal constant RIVER_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.riverAddress")) - 1)
```


## Functions
### get

Retrieve the River Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The River Address|


### set

Sets the River Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New River Address|


