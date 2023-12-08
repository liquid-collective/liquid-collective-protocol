# IAllowlistV1

*Kiln*

> Allowlist Interface (v1)

This interface exposes methods to handle the list of allowed recipients.



## Methods

### getAllower

```solidity
function getAllower() external view returns (address)
```

Retrieves the allower address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The address of the allower |

### getDenier

```solidity
function getDenier() external view returns (address)
```

Retrieves the denier address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The address of the denier |

### getPermissions

```solidity
function getPermissions(address _account) external view returns (uint256)
```

This method retrieves the raw permission value



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | Recipient to verify |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The raw permissions value of the account |

### hasPermission

```solidity
function hasPermission(address _account, uint256 _mask) external view returns (bool)
```

This method returns true if the user has the expected permission         ignoring any deny list membership



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | Recipient to verify |
| _mask | uint256 | Combination of permissions to verify |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if mask is respected |

### initAllowlistV1

```solidity
function initAllowlistV1(address _admin, address _allower) external nonpayable
```

Initializes the allowlist



#### Parameters

| Name | Type | Description |
|---|---|---|
| _admin | address | Address of the Allowlist administrator |
| _allower | address | Address of the allower |

### initAllowlistV1_1

```solidity
function initAllowlistV1_1(address _denier) external nonpayable
```

Initializes the allowlist denier



#### Parameters

| Name | Type | Description |
|---|---|---|
| _denier | address | Address of the denier |

### isAllowed

```solidity
function isAllowed(address _account, uint256 _mask) external view returns (bool)
```

This method returns true if the user has the expected permission and         is not in the deny list



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | Recipient to verify |
| _mask | uint256 | Combination of permissions to verify |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if mask is respected and user is allowed |

### isDenied

```solidity
function isDenied(address _account) external view returns (bool)
```

This method returns true if the user is in the deny list



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | Recipient to verify |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if user is denied access |

### onlyAllowed

```solidity
function onlyAllowed(address _account, uint256 _mask) external view
```

This method should be used as a modifier and is expected to revert         if the user hasn&#39;t got the required permission or if the user is         in the deny list.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | Recipient to verify |
| _mask | uint256 | Combination of permissions to verify |

### setAllowPermissions

```solidity
function setAllowPermissions(address[] _accounts, uint256[] _permissions) external nonpayable
```

Sets the allow permissions for one or more accounts

*This function is for allocating or removing deposit, redeem or donate permissions.      This function could be used to give any permissions that we come up with in the future.      An address which was denied has to be undenied first before they could be given any permission(s).*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _accounts | address[] | Accounts to update |
| _permissions | uint256[] | New permission values |

### setAllower

```solidity
function setAllower(address _newAllowerAddress) external nonpayable
```

Changes the allower address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAllowerAddress | address | New address allowed to edit the allowlist |

### setDenier

```solidity
function setDenier(address _newDenierAddress) external nonpayable
```

Changes the denier address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newDenierAddress | address | New address allowed to edit the allowlist |

### setDenyPermissions

```solidity
function setDenyPermissions(address[] _accounts, uint256[] _permissions) external nonpayable
```

Sets the deny permissions for one or more accounts

*This function is for allocating or removing deny permissions.      An address which is undenied has to be given permissions again for them to be able to deposit, donate or redeem.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _accounts | address[] | Accounts to update |
| _permissions | uint256[] | New permission values |



## Events

### SetAllower

```solidity
event SetAllower(address indexed allower)
```

The stored allower address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| allower `indexed` | address | The new allower address |

### SetAllowlistPermissions

```solidity
event SetAllowlistPermissions(address[] accounts, uint256[] permissions)
```

The permissions of several accounts have changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| accounts  | address[] | List of accounts |
| permissions  | uint256[] | New permissions for each account at the same index |

### SetDenier

```solidity
event SetDenier(address indexed denier)
```

The stored denier address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| denier `indexed` | address | The new denier address |



## Errors

### AttemptToRemoveDenyPermission

```solidity
error AttemptToRemoveDenyPermission()
```

Allower can&#39;t remove deny permission




### AttemptToSetDenyPermission

```solidity
error AttemptToSetDenyPermission()
```

Invalid permission being set




### Denied

```solidity
error Denied(address _account)
```

The account is denied access



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | The denied account |

### InvalidCount

```solidity
error InvalidCount()
```

The provided accounts list is empty




### MismatchedAlloweeAndStatusCount

```solidity
error MismatchedAlloweeAndStatusCount()
```

The provided accounts and permissions list have different lengths





