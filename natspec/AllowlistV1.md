# AllowlistV1

*Kiln*

> Allowlist (v1)

This contract handles the list of allowed recipients.



## Methods

### allow

```solidity
function allow(address[] _accounts, uint256[] _statuses) external nonpayable
```

Sets the allowlisting status for one or more accounts



#### Parameters

| Name | Type | Description |
|---|---|---|
| _accounts | address[] | Accounts with statuses to edit |
| _statuses | uint256[] | Allowlist statuses for each account, in the same order as _accounts |

### getAllower

```solidity
function getAllower() external view returns (address)
```

Retrieves the allower address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

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
| _0 | uint256 | undefined |

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
| _0 | bool | undefined |

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
| _0 | bool | undefined |

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
| _0 | bool | undefined |

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

### ChangedAllowlistStatuses

```solidity
event ChangedAllowlistStatuses(address[] indexed accounts, uint256[] statuses)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| accounts `indexed` | address[] | undefined |
| statuses  | uint256[] | undefined |



## Errors

### Denied

```solidity
error Denied(address _account)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |

### InvalidAlloweeCount

```solidity
error InvalidAlloweeCount()
```






### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | undefined |
| expectedVersion | uint256 | undefined |

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```






### MismatchedAlloweeAndStatusCount

```solidity
error MismatchedAlloweeAndStatusCount()
```






### Unauthorized

```solidity
error Unauthorized(address caller)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | undefined |


