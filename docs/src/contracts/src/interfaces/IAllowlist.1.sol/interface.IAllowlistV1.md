# IAllowlistV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/IAllowlist.1.sol)

**Title:**
Allowlist Interface (v1)

**Author:**
Alluvial Finance Inc.

This interface exposes methods to handle the list of allowed recipients.


## Functions
### initAllowlistV1

Initializes the allowlist


```solidity
function initAllowlistV1(address _admin, address _allower) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Address of the Allowlist administrator|
|`_allower`|`address`|Address of the allower|


### initAllowlistV1_1

Initializes the allowlist denier


```solidity
function initAllowlistV1_1(address _denier) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denier`|`address`|Address of the denier|


### getAllower

Retrieves the allower address


```solidity
function getAllower() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the allower|


### getDenier

Retrieves the denier address


```solidity
function getDenier() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the denier|


### isAllowed

This method returns true if the user has the expected permission and
is not in the deny list


```solidity
function isAllowed(address _account, uint256 _mask) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Recipient to verify|
|`_mask`|`uint256`|Combination of permissions to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if mask is respected and user is allowed|


### isDenied

This method returns true if the user is in the deny list


```solidity
function isDenied(address _account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Recipient to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if user is denied access|


### hasPermission

This method returns true if the user has the expected permission
ignoring any deny list membership


```solidity
function hasPermission(address _account, uint256 _mask) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Recipient to verify|
|`_mask`|`uint256`|Combination of permissions to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if mask is respected|


### getPermissions

This method retrieves the raw permission value


```solidity
function getPermissions(address _account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Recipient to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The raw permissions value of the account|


### onlyAllowed

This method should be used as a modifier and is expected to revert
if the user hasn't got the required permission or if the user is
in the deny list.


```solidity
function onlyAllowed(address _account, uint256 _mask) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Recipient to verify|
|`_mask`|`uint256`|Combination of permissions to verify|


### setAllower

Changes the allower address


```solidity
function setAllower(address _newAllowerAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newAllowerAddress`|`address`|New address allowed to edit the allowlist|


### setDenier

Changes the denier address


```solidity
function setDenier(address _newDenierAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newDenierAddress`|`address`|New address allowed to edit the allowlist|


### setAllowPermissions

Sets the allow permissions for one or more accounts

This function is for allocating or removing deposit, redeem or donate permissions.
This function could be used to give any permissions that we come up with in the future.
An address which was denied has to be undenied first before they could be given any permission(s).


```solidity
function setAllowPermissions(address[] calldata _accounts, uint256[] calldata _permissions) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_accounts`|`address[]`|Accounts to update|
|`_permissions`|`uint256[]`|New permission values|


### setDenyPermissions

Sets the deny permissions for one or more accounts

This function is for allocating or removing deny permissions.
An address which is undenied has to be given permissions again for them to be able to deposit, donate or redeem.


```solidity
function setDenyPermissions(address[] calldata _accounts, uint256[] calldata _permissions) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_accounts`|`address[]`|Accounts to update|
|`_permissions`|`uint256[]`|New permission values|


## Events
### SetAllowlistPermissions
The permissions of several accounts have changed


```solidity
event SetAllowlistPermissions(address[] accounts, uint256[] permissions);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accounts`|`address[]`|List of accounts|
|`permissions`|`uint256[]`|New permissions for each account at the same index|

### SetAllower
The stored allower address has been changed


```solidity
event SetAllower(address indexed allower);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`allower`|`address`|The new allower address|

### SetDenier
The stored denier address has been changed


```solidity
event SetDenier(address indexed denier);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`denier`|`address`|The new denier address|

## Errors
### InvalidCount
The provided accounts list is empty


```solidity
error InvalidCount();
```

### Denied
The account is denied access


```solidity
error Denied(address _account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The denied account|

### MismatchedArrayLengths
The provided accounts and permissions list have different lengths


```solidity
error MismatchedArrayLengths();
```

### AttemptToSetDenyPermission
Allower can't set deny permission


```solidity
error AttemptToSetDenyPermission();
```

### AttemptToRemoveDenyPermission
Allower can't remove deny permission


```solidity
error AttemptToRemoveDenyPermission();
```

