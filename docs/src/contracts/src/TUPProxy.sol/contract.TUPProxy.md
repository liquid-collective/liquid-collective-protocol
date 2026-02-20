# TUPProxy
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/TUPProxy.sol)

**Inherits:**
TransparentUpgradeableProxy

**Title:**
TUPProxy (Transparent Upgradeable Pausable Proxy)

**Author:**
Alluvial Finance Inc.

This contract extends the Transparent Upgradeable proxy and adds a system wide pause feature.
When the system is paused, the fallback will fail no matter what calls are made.
Address Zero is allowed to perform calls even if paused to allow view calls made
from RPC providers to properly work.


## State Variables
### _PAUSE_SLOT
Storage slot of the pause status value


```solidity
bytes32 private constant _PAUSE_SLOT = bytes32(uint256(keccak256("river.tupproxy.pause")) - 1)
```


## Functions
### constructor

The Admin of the proxy should not be the same as the

admin on the implementation logics. The admin here is

the only account allowed to perform calls on the proxy

(the calls are never delegated to the implementation)


```solidity
constructor(address _logic, address __admin, bytes memory _data)
    payable
    TransparentUpgradeableProxy(_logic, __admin, _data);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_logic`|`address`|Address of the implementation|
|`__admin`|`address`|Address of the admin in charge of the proxy|
|`_data`|`bytes`|Calldata for an atomic initialization|


### paused

Retrieves Paused state


```solidity
function paused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Paused state|


### pause

Pauses system


```solidity
function pause() external ifAdmin;
```

### unpause

Unpauses system


```solidity
function unpause() external ifAdmin;
```

### _beforeFallback

Overrides the fallback method to check if system is not paused before

Address Zero is allowed to perform calls even if system is paused. This allows
view functions to be called when the system is paused as rpc providers can easily
set the sender address to zero.


```solidity
function _beforeFallback() internal override;
```

## Events
### Paused
The system is now paused


```solidity
event Paused(address admin);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|The admin at the time of the pause event|

### Unpaused
The system is now unpaused


```solidity
event Unpaused(address admin);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|The admin at the time of the unpause event|

## Errors
### CallWhenPaused
A call happened while the system was paused


```solidity
error CallWhenPaused();
```

