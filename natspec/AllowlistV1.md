# AllowlistV1

*SkillZ*

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

Verify if a user has a specific right



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | Address to verify |
| _mask | uint256 | Right represented as a bit mask |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

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


