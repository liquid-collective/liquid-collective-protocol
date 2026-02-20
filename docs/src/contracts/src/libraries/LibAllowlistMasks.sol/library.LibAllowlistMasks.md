# LibAllowlistMasks
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/libraries/LibAllowlistMasks.sol)

**Title:**
Lib Allowlist Masks

Holds all the mask values


## State Variables
### DENY_MASK
Mask used for denied accounts


```solidity
uint256 internal constant DENY_MASK = 0x1 << 255
```


### DEPOSIT_MASK
The mask for the deposit right


```solidity
uint256 internal constant DEPOSIT_MASK = 0x1
```


### DONATE_MASK
The mask for the donation right


```solidity
uint256 internal constant DONATE_MASK = 0x1 << 1
```


### REDEEM_MASK
The mask for the redeem right


```solidity
uint256 internal constant REDEEM_MASK = 0x1 << 2
```


