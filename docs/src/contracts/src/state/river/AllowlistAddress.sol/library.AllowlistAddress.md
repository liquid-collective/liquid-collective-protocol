# AllowlistAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/AllowlistAddress.sol)

**Title:**
Allowlist Address Storage

Utility to manage the Allowlist Address in storage


## State Variables
### ALLOWLIST_ADDRESS_SLOT
Storage slot of the Allowlist Address


```solidity
bytes32 internal constant ALLOWLIST_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.allowlistAddress")) - 1)
```


## Functions
### get

Retrieve the Allowlist Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Allowlist Address|


### set

Sets the Allowlist Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Allowlist Address|


