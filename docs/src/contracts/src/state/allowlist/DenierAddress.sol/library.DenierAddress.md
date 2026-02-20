# DenierAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/allowlist/DenierAddress.sol)

**Title:**
Denier Address Storage

Utility to manage the Denier Address in storage


## State Variables
### DENIER_ADDRESS_SLOT
Storage slot of the Denier Address


```solidity
bytes32 internal constant DENIER_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.denierAddress")) - 1)
```


## Functions
### get

Retrieve the Denier Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Denier Address|


### set

Sets the Denier Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Denier Address|


