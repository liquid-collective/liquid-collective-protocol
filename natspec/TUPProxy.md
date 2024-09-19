# TUPProxy

*Alluvial Finance Inc.*

> TUPProxy (Transparent Upgradeable Pausable Proxy)

This contract extends the Transparent Upgradeable proxy and adds a system wide pause feature.         When the system is paused, the fallback will fail no matter what calls are made.         Address Zero is allowed to perform calls even if paused to allow view calls made         from RPC providers to properly work.



## Methods

### pause

```solidity
function pause() external nonpayable
```



*Pauses system*


### paused

```solidity
function paused() external view returns (bool)
```



*Retrieves Paused state*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Paused state |

### unpause

```solidity
function unpause() external nonpayable
```



*Unpauses system*




## Events

### AdminChanged

```solidity
event AdminChanged(address previousAdmin, address newAdmin)
```



*Emitted when the admin account has changed.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| previousAdmin  | address | undefined |
| newAdmin  | address | undefined |

### BeaconUpgraded

```solidity
event BeaconUpgraded(address indexed beacon)
```



*Emitted when the beacon is changed.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| beacon `indexed` | address | undefined |

### Paused

```solidity
event Paused(address admin)
```

The system is now paused



#### Parameters

| Name | Type | Description |
|---|---|---|
| admin  | address | The admin at the time of the pause event |

### Unpaused

```solidity
event Unpaused(address admin)
```

The system is now unpaused



#### Parameters

| Name | Type | Description |
|---|---|---|
| admin  | address | The admin at the time of the unpause event |

### Upgraded

```solidity
event Upgraded(address indexed implementation)
```



*Emitted when the implementation is upgraded.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| implementation `indexed` | address | undefined |



## Errors

### CallWhenPaused

```solidity
error CallWhenPaused()
```

A call happened while the system was paused





