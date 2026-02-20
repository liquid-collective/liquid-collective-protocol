# Firewall
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/Firewall.sol)

**Inherits:**
[IFirewall](/contracts/src/interfaces/IFirewall.sol/interface.IFirewall.md), [IProtocolVersion](/contracts/src/interfaces/IProtocolVersion.sol/interface.IProtocolVersion.md), [Administrable](/contracts/src/Administrable.sol/abstract.Administrable.md)

**Title:**
Firewall

**Author:**
Figment

This contract accepts calls to admin-level functions of an underlying contract, and
ensures the caller holds an appropriate role for calling that function. There are two roles:
- An Admin can call anything
- An Executor can call specific functions. The list of function is customisable.
Random callers cannot call anything through this contract, even if the underlying function
is unpermissioned in the underlying contract.
Calls to non-admin functions should be called at the underlying contract directly.


## State Variables
### executor
Retrieve the executor address


```solidity
address public executor
```


### destination
Retrieve the destination address


```solidity
address public immutable destination
```


### executorCanCall

```solidity
mapping(bytes4 => bool) public executorCanCall
```


## Functions
### constructor


```solidity
constructor(address _admin, address _executor, address _destination, bytes4[] memory _executorCallableSelectors) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Address of the administrator, that is able to perform all calls via the Firewall|
|`_executor`|`address`|Address of the executor, that is able to perform only a subset of calls via the Firewall|
|`_destination`|`address`||
|`_executorCallableSelectors`|`bytes4[]`|Initial list of allowed selectors for the executor|


### onlyAdminOrExecutor

Prevents unauthorized calls


```solidity
modifier onlyAdminOrExecutor() ;
```

### setExecutor

Sets the executor address


```solidity
function setExecutor(address _newExecutor) external onlyAdminOrExecutor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newExecutor`|`address`|New address for the executor|


### allowExecutor

Sets the permission for a function selector


```solidity
function allowExecutor(bytes4 _functionSelector, bool _executorCanCall) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_functionSelector`|`bytes4`|Method signature on which the permission is changed|
|`_executorCanCall`|`bool`|True if selector is callable by the executor|


### fallback

Fallback method. All its parameters are forwarded to the destination if caller is authorized


```solidity
fallback() external payable virtual;
```

### receive

Receive fallback method. All its parameters are forwarded to the destination if caller is authorized


```solidity
receive() external payable virtual;
```

### _checkCallerRole

Performs call checks to verify that the caller is able to perform the call


```solidity
function _checkCallerRole() internal view;
```

### _forward

Forwards the current call parameters to the destination address


```solidity
function _forward(address _destination, uint256 _value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_destination`|`address`|Address on which the forwarded call is performed|
|`_value`|`uint256`|Message value to attach to the call|


### _fallback

Internal utility to perform authorization checks and forward a call


```solidity
function _fallback() internal virtual;
```

### version

Retrieves the version of the contract


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Version of the contract|


