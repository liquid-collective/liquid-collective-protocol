# Quorum
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/oracle/Quorum.sol)

**Title:**
Quorum Storage

Utility to manage the Quorum in storage


## State Variables
### QUORUM_SLOT
Storage slot of the Quorum


```solidity
bytes32 internal constant QUORUM_SLOT = bytes32(uint256(keccak256("river.state.quorum")) - 1)
```


## Functions
### get

Retrieve the Quorum


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Quorum|


### set

Sets the Quorum


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New Quorum|


