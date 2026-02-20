# LibAdministrable
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/libraries/LibAdministrable.sol)

**Title:**
Lib Administrable

**Author:**
Alluvial Finance Inc.

This library handles the admin and pending admin storage vars


## Functions
### _getAdmin

Retrieve the system admin


```solidity
function _getAdmin() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the system admin|


### _getPendingAdmin

Retrieve the pending system admin


```solidity
function _getPendingAdmin() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The adress of the pending system admin|


### _setAdmin

Sets the system admin


```solidity
function _setAdmin(address _admin) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|New system admin|


### _setPendingAdmin

Sets the pending system admin


```solidity
function _setPendingAdmin(address _pendingAdmin) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pendingAdmin`|`address`|New pending system admin|


