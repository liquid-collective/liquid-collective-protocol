# AllowlistV1

*Kiln*

> Allowlist (v1)

This contract handles the list of allowed recipients.All accounts have an uint256 value associated with their addresses whereeach bit represents a right in the system. The DENY_MASK defined the maskused to identify if the denied bit is on, preventing users from interactingwith the system



## Methods

### acceptAdmin

```solidity
function acceptAdmin() external nonpayable
```

Accept the transfer of ownership

*Only callable by the pending admin. Resets the pending admin if succesful.*


### allow

```solidity
function allow(address[] _accounts, uint256[] _permissions) external nonpayable
```

Sets the allowlisting status for one or more accounts

*The permission value is overridden and not updated*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _accounts | address[] | Accounts with statuses to edit |
| _permissions | uint256[] | Allowlist permissions for each account, in the same order as _accounts |

### getAdmin

```solidity
function getAdmin() external view returns (address)
```

Retrieves the current admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The admin address |

### getAllower

```solidity
function getAllower() external view returns (address)
```

Retrieves the allower address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The address of the allower |

### getPendingAdmin

```solidity
function getPendingAdmin() external view returns (address)
```

Retrieve the current pending admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The pending admin address |

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

### proposeAdmin

```solidity
function proposeAdmin(address _newAdmin) external nonpayable
```

Proposes a new address as admin

*This security prevents setting an invalid address as an admin. The pendingadmin has to claim its ownership of the contract, and prove that the newaddress is able to perform regular transactions.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | New admin address |

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

### Initialize

```solidity
event Initialize(uint256 version, bytes cdata)
```

Emitted when the contract is properly initialized



#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint256 | undefined |
| cdata  | bytes | undefined |

### SetAdmin

```solidity
event SetAdmin(address indexed admin)
```

The admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| admin `indexed` | address | undefined |

### SetAllower

```solidity
event SetAllower(address indexed allower)
```

The stored allower address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| allower `indexed` | address | undefined |

### SetAllowlistPermissions

```solidity
event SetAllowlistPermissions(address[] indexed accounts, uint256[] permissions)
```

The permissions of several accounts have changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| accounts `indexed` | address[] | undefined |
| permissions  | uint256[] | undefined |

### SetPendingAdmin

```solidity
event SetPendingAdmin(address indexed pendingAdmin)
```

The pending admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| pendingAdmin `indexed` | address | undefined |



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




### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```

An error occured during the initialization



#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | The version that was attempting to be initialized |
| expectedVersion | uint256 | The version that was expected |

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero




### MismatchedAlloweeAndStatusCount

```solidity
error MismatchedAlloweeAndStatusCount()
```

The provided accounts and permissions list have different lengths




### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Address performing the call |


