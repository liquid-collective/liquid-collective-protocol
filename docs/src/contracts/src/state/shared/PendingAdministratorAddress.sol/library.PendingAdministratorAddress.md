# PendingAdministratorAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/shared/PendingAdministratorAddress.sol)

**Title:**
Pending Administrator Address Storage

Utility to manage the Pending Administrator Address in storage


## State Variables
### PENDING_ADMINISTRATOR_ADDRESS_SLOT
Storage slot of the Pending Administrator Address


```solidity
bytes32 public constant PENDING_ADMINISTRATOR_ADDRESS_SLOT =
    bytes32(uint256(keccak256("river.state.pendingAdministratorAddress")) - 1)
```


## Functions
### get

Retrieve the Pending Administrator Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Pending Administrator Address|


### set

Sets the Pending Administrator Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Pending Administrator Address|


