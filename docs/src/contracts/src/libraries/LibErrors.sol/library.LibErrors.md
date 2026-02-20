# LibErrors
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/libraries/LibErrors.sol)

**Title:**
Lib Errors

Library of common errors


## Errors
### Unauthorized
The operator is unauthorized for the caller


```solidity
error Unauthorized(address caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|Address performing the call|

### InvalidCall
The call was invalid


```solidity
error InvalidCall();
```

### InvalidArgument
The argument was invalid


```solidity
error InvalidArgument();
```

### InvalidZeroAddress
The address is zero


```solidity
error InvalidZeroAddress();
```

### InvalidEmptyString
The string is empty


```solidity
error InvalidEmptyString();
```

### InvalidFee
The fee is invalid


```solidity
error InvalidFee();
```

