# Shares
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/Shares.sol)

**Title:**
Shares Count Storage

Utility to manage the Shares Count in storage


## State Variables
### SHARES_SLOT
Storage slot of the Shares Count


```solidity
bytes32 internal constant SHARES_SLOT = bytes32(uint256(keccak256("river.state.shares")) - 1)
```


## Functions
### get

Retrieve the Shares Count


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Shares Count|


### set

Sets the Shares Count


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New Shares Count|


