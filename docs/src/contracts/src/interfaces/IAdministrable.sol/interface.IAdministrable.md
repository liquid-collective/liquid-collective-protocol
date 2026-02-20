# IAdministrable
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/IAdministrable.sol)

**Title:**
Administrable Interface

**Author:**
Alluvial Finance Inc.

This interface exposes methods to handle the ownership of the contracts


## Functions
### getAdmin

Retrieves the current admin address


```solidity
function getAdmin() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The admin address|


### getPendingAdmin

Retrieve the current pending admin address


```solidity
function getPendingAdmin() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The pending admin address|


### proposeAdmin

Proposes a new address as admin

This security prevents setting an invalid address as an admin. The pending

admin has to claim its ownership of the contract, and prove that the new

address is able to perform regular transactions.


```solidity
function proposeAdmin(address _newAdmin) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newAdmin`|`address`|New admin address|


### acceptAdmin

Accept the transfer of ownership

Only callable by the pending admin. Resets the pending admin if succesful.


```solidity
function acceptAdmin() external;
```

## Events
### SetPendingAdmin
The pending admin address changed


```solidity
event SetPendingAdmin(address indexed pendingAdmin);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pendingAdmin`|`address`|New pending admin address|

### SetAdmin
The admin address changed


```solidity
event SetAdmin(address indexed admin);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|New admin address|

