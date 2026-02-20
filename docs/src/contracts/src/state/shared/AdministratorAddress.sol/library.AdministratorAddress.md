# AdministratorAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/shared/AdministratorAddress.sol)

**Title:**
Administrator Address Storage

Utility to manage the Administrator Address in storage


## State Variables
### ADMINISTRATOR_ADDRESS_SLOT
Storage slot of the Administrator Address


```solidity
bytes32 public constant ADMINISTRATOR_ADDRESS_SLOT =
    bytes32(uint256(keccak256("river.state.administratorAddress")) - 1)
```


## Functions
### get

Retrieve the Administrator Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Administrator Address|


### set

Sets the Administrator Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Administrator Address|


