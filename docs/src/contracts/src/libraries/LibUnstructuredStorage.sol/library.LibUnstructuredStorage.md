# LibUnstructuredStorage
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/libraries/LibUnstructuredStorage.sol)

**Title:**
Lib Unstructured Storage

Utilities to work with unstructured storage


## Functions
### getStorageBool

Retrieve a bool value at a storage slot


```solidity
function getStorageBool(bytes32 _position) internal view returns (bool data);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_position`|`bytes32`|The storage slot to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bool`|The bool value|


### getStorageAddress

Retrieve an address value at a storage slot


```solidity
function getStorageAddress(bytes32 _position) internal view returns (address data);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_position`|`bytes32`|The storage slot to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`data`|`address`|The address value|


### getStorageBytes32

Retrieve a bytes32 value at a storage slot


```solidity
function getStorageBytes32(bytes32 _position) internal view returns (bytes32 data);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_position`|`bytes32`|The storage slot to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes32`|The bytes32 value|


### getStorageUint256

Retrieve an uint256 value at a storage slot


```solidity
function getStorageUint256(bytes32 _position) internal view returns (uint256 data);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_position`|`bytes32`|The storage slot to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`data`|`uint256`|The uint256 value|


### setStorageBool

Sets a bool value at a storage slot


```solidity
function setStorageBool(bytes32 _position, bool _data) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_position`|`bytes32`|The storage slot to set|
|`_data`|`bool`|The bool value to set|


### setStorageAddress

Sets an address value at a storage slot


```solidity
function setStorageAddress(bytes32 _position, address _data) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_position`|`bytes32`|The storage slot to set|
|`_data`|`address`|The address value to set|


### setStorageBytes32

Sets a bytes32 value at a storage slot


```solidity
function setStorageBytes32(bytes32 _position, bytes32 _data) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_position`|`bytes32`|The storage slot to set|
|`_data`|`bytes32`|The bytes32 value to set|


### setStorageUint256

Sets an uint256 value at a storage slot


```solidity
function setStorageUint256(bytes32 _position, uint256 _data) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_position`|`bytes32`|The storage slot to set|
|`_data`|`uint256`|The uint256 value to set|


