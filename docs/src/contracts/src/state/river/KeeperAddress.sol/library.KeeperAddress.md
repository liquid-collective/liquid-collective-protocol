# KeeperAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/KeeperAddress.sol)

**Title:**
Keeper Address Storage

Utility to manage the Keeper Address in storage


## State Variables
### KEEPER_ADDRESS_SLOT
Storage slot of the Keeper Address


```solidity
bytes32 internal constant KEEPER_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.KeeperAddress")) - 1)
```


## Functions
### get

Retrieve the Keeper Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Keeper Address|


### set

Sets the Keeper Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Keeper Address|


