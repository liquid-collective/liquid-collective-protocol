# IFirewall
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/IFirewall.sol)

**Title:**
Firewall

**Author:**
Figment

This interface exposes methods to accept calls to admin-level functions of an underlying contract.


## Functions
### executor

Retrieve the executor address


```solidity
function executor() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The executor address|


### destination

Retrieve the destination address


```solidity
function destination() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The destination address|


### executorCanCall

Returns true if the executor is allowed to perform a call on the given selector


```solidity
function executorCanCall(bytes4 _selector) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_selector`|`bytes4`|The selector to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if executor is allowed to call|


### setExecutor

Sets the executor address


```solidity
function setExecutor(address _newExecutor) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newExecutor`|`address`|New address for the executor|


### allowExecutor

Sets the permission for a function selector


```solidity
function allowExecutor(bytes4 _functionSelector, bool _executorCanCall) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_functionSelector`|`bytes4`|Method signature on which the permission is changed|
|`_executorCanCall`|`bool`|True if selector is callable by the executor|


### fallback

Fallback method. All its parameters are forwarded to the destination if caller is authorized


```solidity
fallback() external payable;
```

### receive

Receive fallback method. All its parameters are forwarded to the destination if caller is authorized


```solidity
receive() external payable;
```

## Events
### SetExecutor
The stored executor address has been changed


```solidity
event SetExecutor(address indexed executor);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`executor`|`address`|The new executor address|

### SetDestination
The stored destination address has been changed


```solidity
event SetDestination(address indexed destination);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`destination`|`address`|The new destination address|

### SetExecutorPermissions
The storage permission for a selector has been changed


```solidity
event SetExecutorPermissions(bytes4 selector, bool status);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The 4 bytes method selector|
|`status`|`bool`|True if executor is allowed|

