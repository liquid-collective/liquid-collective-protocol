# IFirewall









## Methods

### allowExecutor

```solidity
function allowExecutor(bytes4 functionSelector, bool executorCanCall_) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| functionSelector | bytes4 | undefined |
| executorCanCall_ | bool | undefined |

### setExecutor

```solidity
function setExecutor(address newExecutor) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newExecutor | address | undefined |



## Events

### SetDestination

```solidity
event SetDestination(address indexed destination)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| destination `indexed` | address | undefined |

### SetExecutor

```solidity
event SetExecutor(address indexed executor)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| executor `indexed` | address | undefined |

### SetExecutorPermissions

```solidity
event SetExecutorPermissions(bytes4 selector, bool status)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| selector  | bytes4 | undefined |
| status  | bool | undefined |



