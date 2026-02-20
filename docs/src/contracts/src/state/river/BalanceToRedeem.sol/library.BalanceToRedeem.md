# BalanceToRedeem
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/BalanceToRedeem.sol)


## State Variables
### BALANCE_TO_REDEEM_SLOT

```solidity
bytes32 internal constant BALANCE_TO_REDEEM_SLOT = bytes32(uint256(keccak256("river.state.balanceToRedeem")) - 1)
```


## Functions
### get


```solidity
function get() internal view returns (uint256);
```

### set


```solidity
function set(uint256 newValue) internal;
```

