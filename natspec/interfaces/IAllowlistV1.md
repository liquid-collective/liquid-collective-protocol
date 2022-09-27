# IAllowlistV1









## Methods

### allow

```solidity
function allow(address[] _accounts, uint256[] _permissions) external nonpayable
```

Sets the allowlisting status for one or more accounts

*The permission value is overriden and not updated*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _accounts | address[] | Accounts with statuses to edit |
| _permissions | uint256[] | Allowlist permissions for each account, in the same order as _accounts |

### getAllower

```solidity
function getAllower() external view returns (address)
```

Retrieves the allower address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The address of the allower |

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
| _0 | bool | True if mask is respected and user is not allowed |

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

### setAllower

```solidity
function setAllower(address _newAllowerAddress) external nonpayable
```

Changes the allower address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAllowerAddress | address | New address allowed to edit the allowlist |



## Events

### SetAllower

```solidity
event SetAllower(address indexed allower)
```

The stored allowee address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| allower `indexed` | address | The new allower address |

### SetAllowlistPermissions

```solidity
event SetAllowlistPermissions(address[] indexed accounts, uint256[] permissions)
```

The permissions of several accounts have changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| accounts `indexed` | address[] | List of accounts |
| permissions  | uint256[] | New permissions for each account at the same index |



## Errors

### Denied

```solidity
error Denied(address _account)
```

The account is denied access



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | The denied account |

### InvalidAlloweeCount

```solidity
error InvalidAlloweeCount()
```

The provided accounts list is empty




### MismatchedAlloweeAndStatusCount

```solidity
error MismatchedAlloweeAndStatusCount()
```

The provided accounts and permissions list have different lengths





