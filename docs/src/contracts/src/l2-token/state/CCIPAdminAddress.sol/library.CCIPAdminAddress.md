# CCIPAdminAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/l2-token/state/CCIPAdminAddress.sol)

**Title:**
CCIPAdmin Address Storage

Utility to manage the CCIPAdmin Address in storage


## State Variables
### CCIP_ADMIN_ADDRESS_SLOT
Storage slot of the CCIPAdmin Address


```solidity
bytes32 internal constant CCIP_ADMIN_ADDRESS_SLOT = bytes32(uint256(keccak256("state.ccipAdminAddress")) - 1)
```


## Functions
### get

Retrieve the CCIPAdmin Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The CCIPAdmin Address|


### set

Sets the CCIPAdmin Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New CCIPAdmin Address|


