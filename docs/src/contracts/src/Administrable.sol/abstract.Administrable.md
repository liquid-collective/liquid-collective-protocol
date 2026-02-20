# Administrable
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/Administrable.sol)

**Inherits:**
[IAdministrable](/contracts/src/interfaces/IAdministrable.sol/interface.IAdministrable.md)

**Title:**
Administrable

**Author:**
Alluvial Finance Inc.

This contract handles the administration of the contracts


## Functions
### onlyAdmin

Prevents unauthorized calls


```solidity
modifier onlyAdmin() ;
```

### onlyPendingAdmin

Prevents unauthorized calls


```solidity
modifier onlyPendingAdmin() ;
```

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


```solidity
function proposeAdmin(address _newAdmin) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newAdmin`|`address`|New admin address|


### acceptAdmin

Accept the transfer of ownership

Only callable by the pending admin. Resets the pending admin if succesful.


```solidity
function acceptAdmin() external onlyPendingAdmin;
```

### _setAdmin

Internal utility to set the admin address


```solidity
function _setAdmin(address _admin) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Address to set as admin|


### _setPendingAdmin

Internal utility to set the pending admin address


```solidity
function _setPendingAdmin(address _pendingAdmin) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pendingAdmin`|`address`|Address to set as pending admin|


### _getAdmin

Internal utility to retrieve the address of the current admin


```solidity
function _getAdmin() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of admin|


