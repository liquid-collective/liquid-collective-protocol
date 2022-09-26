# IFirewall









## Methods

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

### SetDestination

```solidity
event SetDestination(address indexed destination)
```

The stored destination address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| destination `indexed` | address | The new destination address |

### SetExecutor

```solidity
event SetExecutor(address indexed executor)
```

The stored executor address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| executor `indexed` | address | The new executor address |

### SetExecutorPermissions

```solidity
event SetExecutorPermissions(bytes4 selector, bool status)
```

The storage permission for a selector has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| selector  | bytes4 | The 4 bytes method selector |
| status  | bool | True if executor is allowed |



