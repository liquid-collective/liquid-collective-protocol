# LibBytes
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/libraries/LibBytes.sol)

**Title:**
Lib Bytes

This library helps manipulating bytes


## Functions
### slice

Slices the provided bytes


```solidity
function slice(bytes memory _bytes, uint256 _start, uint256 _length) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bytes`|`bytes`|Bytes to slice|
|`_start`|`uint256`|The starting index of the slice|
|`_length`|`uint256`|The length of the slice|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The slice of _bytes starting at _start of length _length|


## Errors
### SliceOverflow
The length overflows an uint


```solidity
error SliceOverflow();
```

### SliceOutOfBounds
The slice is outside of the initial bytes bounds


```solidity
error SliceOutOfBounds();
```

