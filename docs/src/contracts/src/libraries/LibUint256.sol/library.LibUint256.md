# LibUint256
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/libraries/LibUint256.sol)

**Title:**
Lib Uint256

Utilities to perform uint operations


## Functions
### toLittleEndian64

Converts a value to little endian (64 bits)


```solidity
function toLittleEndian64(uint256 _value) internal pure returns (uint256 result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_value`|`uint256`|The value to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`uint256`|The converted value|


### min

Returns the minimum value


```solidity
function min(uint256 _a, uint256 _b) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_a`|`uint256`|First value|
|`_b`|`uint256`|Second value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Smallest value between _a and _b|


### max

Returns the max value


```solidity
function max(uint256 _a, uint256 _b) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_a`|`uint256`|First value|
|`_b`|`uint256`|Second value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Highest value between _a and _b|


### ceil

Performs a ceiled division


```solidity
function ceil(uint256 _a, uint256 _b) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_a`|`uint256`|Numerator|
|`_b`|`uint256`|Denominator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|ceil(_a / _b)|


