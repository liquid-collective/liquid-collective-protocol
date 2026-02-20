# AllowerAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/allowlist/AllowerAddress.sol)

**Title:**
Allower Address Storage

Utility to manage the Allower Address in storage


## State Variables
### ALLOWER_ADDRESS_SLOT
Storage slot of the Allower Address


```solidity
bytes32 internal constant ALLOWER_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.allowerAddress")) - 1)
```


## Functions
### get

Retrieve the Allower Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Allower Address|


### set

Sets the Allower Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Allower Address|


