# GlobalFee
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/GlobalFee.sol)

**Title:**
Global Fee Storage

Utility to manage the Global Fee in storage


## State Variables
### GLOBAL_FEE_SLOT
Storage slot of the Global Fee


```solidity
bytes32 internal constant GLOBAL_FEE_SLOT = bytes32(uint256(keccak256("river.state.globalFee")) - 1)
```


## Functions
### get

Retrieve the Global Fee


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Global Fee|


### set

Sets the Global Fee


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New Global Fee|


