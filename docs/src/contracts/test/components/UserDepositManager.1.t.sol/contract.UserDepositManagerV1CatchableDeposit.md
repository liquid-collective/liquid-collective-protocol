# UserDepositManagerV1CatchableDeposit
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/UserDepositManager.1.t.sol)

**Inherits:**
[UserDepositManagerV1](/contracts/src/components/UserDepositManager.1.sol/abstract.UserDepositManagerV1.md)


## Functions
### _onDeposit


```solidity
function _onDeposit(address depositor, address recipient, uint256 amount) internal override;
```

### _setBalanceToDeposit


```solidity
function _setBalanceToDeposit(uint256 newBalanceToDeposit) internal override;
```

## Events
### InternalCallbackCalled

```solidity
event InternalCallbackCalled(address depositor, address recipient, uint256 amount);
```

### SetBalanceToDeposit

```solidity
event SetBalanceToDeposit(uint256 oldAmount, uint256 newAmount);
```

