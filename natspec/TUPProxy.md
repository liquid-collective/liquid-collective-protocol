# TUPProxy

*Kiln*

> TUPProxy (Transparent Upgradeable Pausable Proxy)

This contract extends the Transparent Upgradeable proxy and adds a system wide pause feature.         When the system is paused, the fallback will fail no matter what calls are made.         Address Zero is allowed to perform calls even if paused to allow view calls made         from RPC providers to properly work.



## Methods

### admin

```solidity
function admin() external nonpayable returns (address admin_)
```



*Returns the current admin. NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyAdmin}. TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call. `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`*


#### Returns

| Name | Type | Description |
|---|---|---|
| admin_ | address | undefined |

### changeAdmin

```solidity
function changeAdmin(address newAdmin) external nonpayable
```



*Changes the admin of the proxy. Emits an {AdminChanged} event. NOTE: Only the admin can call this function. See {ProxyAdmin-changeProxyAdmin}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newAdmin | address | undefined |

### implementation

```solidity
function implementation() external nonpayable returns (address implementation_)
```



*Returns the current implementation. NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyImplementation}. TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call. `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`*


#### Returns

| Name | Type | Description |
|---|---|---|
| implementation_ | address | undefined |

### pause

```solidity
function pause() external nonpayable
```



*Pauses system*


### paused

```solidity
function paused() external nonpayable returns (bool)
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


### upgradeTo

```solidity
function upgradeTo(address newImplementation) external nonpayable
```



*Upgrade the implementation of the proxy. NOTE: Only the admin can call this function. See {ProxyAdmin-upgrade}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newImplementation | address | undefined |

### upgradeToAndCall

```solidity
function upgradeToAndCall(address newImplementation, bytes data) external payable
```



*Upgrade the implementation of the proxy, and then call a function from the new implementation as specified by `data`, which should be an encoded function call. This is useful to initialize new storage variables in the proxied contract. NOTE: Only the admin can call this function. See {ProxyAdmin-upgradeAndCall}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newImplementation | address | undefined |
| data | bytes | undefined |



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



*Emitted when the beacon is upgraded.*

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





