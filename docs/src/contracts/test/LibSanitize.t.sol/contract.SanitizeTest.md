# SanitizeTest
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/LibSanitize.t.sol)

**Inherits:**
Test


## State Variables
### si

```solidity
SanitizedInputs internal si
```


## Functions
### setUp


```solidity
function setUp() external;
```

### testSetZeroAddress


```solidity
function testSetZeroAddress() external;
```

### testSetNonZeroAddress


```solidity
function testSetNonZeroAddress() external;
```

### testSetEmptyString


```solidity
function testSetEmptyString() external;
```

### testSetNonEmptyString


```solidity
function testSetNonEmptyString() external view;
```

### testSetFeeTooHigh


```solidity
function testSetFeeTooHigh() external;
```

### testSetValidFee


```solidity
function testSetValidFee() external view;
```

