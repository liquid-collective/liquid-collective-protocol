# Initializable
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/Initializable.sol)

**Title:**
Initializable

**Author:**
Alluvial Finance Inc.

This contract ensures that initializers are called only once per version


## Functions
### constructor

Disable initialization on implementations


```solidity
constructor() ;
```

### init

Use this modifier on initializers along with a hard-coded version number


```solidity
modifier init(uint256 _version) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_version`|`uint256`|Version to initialize|


## Events
### Initialize
Emitted when the contract is properly initialized


```solidity
event Initialize(uint256 version, bytes cdata);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`uint256`|New version of the contracts|
|`cdata`|`bytes`|Complete calldata that was used during the initialization|

## Errors
### InvalidInitialization
An error occured during the initialization


```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`uint256`|The version that was attempting to be initialized|
|`expectedVersion`|`uint256`|The version that was expected|

