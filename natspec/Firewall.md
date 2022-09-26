# Firewall

*Figment*

> Firewall

This contract accepts calls to admin-level functions of an underlying contract, and         ensures the caller holds an appropriate role for calling that function. There are two roles:          - An Admin can call anything          - An Executor can call specific functions specified at construction         Random callers cannot call anything through this contract, even if the underlying function         is unpermissioned in the underlying contract.         Calls to non-admin functions should be called at the underlying contract directly.



## Methods

### acceptAdmin

```solidity
function acceptAdmin() external nonpayable
```

Accept the transfer of ownership

*Only callable by the pending admin. Resets the pending admin if succesful.*


### allowExecutor

```solidity
function allowExecutor(bytes4 _functionSelector, bool _executorCanCall) external nonpayable
```

Sets the permission for a function selector



#### Parameters

| Name | Type | Description |
|---|---|---|
| _functionSelector | bytes4 | Method signature on which the permission is changed |
| _executorCanCall | bool | True if selector is callable by the executor |

### destination

```solidity
function destination() external view returns (address)
```

The destination address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### executor

```solidity
function executor() external view returns (address)
```

The executor address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### executorCanCall

```solidity
function executorCanCall(bytes4) external view returns (bool)
```

Returns true if the executor is allowed to perform a call on the given selector



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### getAdmin

```solidity
function getAdmin() external view returns (address)
```

Retrieves the current admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The admin address |

### getPendingAdmin

```solidity
function getPendingAdmin() external view returns (address)
```

Retrieve the current pending admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The pending admin address |

### proposeAdmin

```solidity
function proposeAdmin(address _newAdmin) external nonpayable
```

Proposes a new address as admin

*This security prevents setting and invalid address as an admin. The pendingadmin has to claim its ownership of the contract, and proves that the newaddress is able to perform regular transactions.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | New admin address |

### setExecutor

```solidity
function setExecutor(address _newExecutor) external nonpayable
```

Sets the executor address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newExecutor | address | New address for the executor |



## Events

### SetAdmin

```solidity
event SetAdmin(address indexed admin)
```

The admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| admin `indexed` | address | undefined |

### SetDestination

```solidity
event SetDestination(address indexed destination)
```

The stored destination address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| destination `indexed` | address | undefined |

### SetExecutor

```solidity
event SetExecutor(address indexed executor)
```

The stored executor address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| executor `indexed` | address | undefined |

### SetExecutorPermissions

```solidity
event SetExecutorPermissions(bytes4 selector, bool status)
```

The storage permission for a selector has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| selector  | bytes4 | undefined |
| status  | bool | undefined |

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

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero




### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Addres performing the call |


