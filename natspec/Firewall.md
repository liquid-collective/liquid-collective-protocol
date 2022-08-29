# Firewall

*Figment*

> Firewall

This contract accepts calls to admin-level functions of an underlying contract, and         ensures the caller holds an appropriate role for calling that function. There are two roles:          - A Governor can call anything          - An Executor can call specific functions specified at construction         Random callers cannot call anything through this contract, even if the underlying function         is unpermissioned in the underlying contract.         Calls to non-admin functions should be called at the underlying contract directly.



## Methods

### allowExecutor

```solidity
function allowExecutor(bytes4 functionSelector, bool executorCanCall_) external nonpayable
```



*make a function either only callable by the governor, or callable by gov and executor.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| functionSelector | bytes4 | undefined |
| executorCanCall_ | bool | undefined |

### executor

```solidity
function executor() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### governor

```solidity
function governor() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### setExecutor

```solidity
function setExecutor(address newExecutor) external nonpayable
```



*Change the executor*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newExecutor | address | undefined |

### setGovernor

```solidity
function setGovernor(address newGovernor) external nonpayable
```



*Change the governor*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newGovernor | address | undefined |




## Errors

### Unauthorized

```solidity
error Unauthorized(address caller)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | undefined |


