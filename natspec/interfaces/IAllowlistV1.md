# IAllowlistV1









## Methods

### allow

```solidity
function allow(address[] _accounts, uint256[] _statuses) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _accounts | address[] | undefined |
| _statuses | uint256[] | undefined |

### getAllower

```solidity
function getAllower() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getPermissions

```solidity
function getPermissions(address _account) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### hasPermission

```solidity
function hasPermission(address _account, uint256 _mask) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |
| _mask | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### initAllowlistV1

```solidity
function initAllowlistV1(address _admin, address _allower) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _admin | address | undefined |
| _allower | address | undefined |

### isAllowed

```solidity
function isAllowed(address _account, uint256 _mask) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |
| _mask | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### isDenied

```solidity
function isDenied(address _account) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### onlyAllowed

```solidity
function onlyAllowed(address _account, uint256 _mask) external view
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |
| _mask | uint256 | undefined |

### setAllower

```solidity
function setAllower(address _newAllowerAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAllowerAddress | address | undefined |



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






### MismatchedAlloweeAndStatusCount

```solidity
error MismatchedAlloweeAndStatusCount()
```






### Unauthorized

```solidity
error Unauthorized(address _account)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |


