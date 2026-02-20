# ELFeeRecipientV1TestBase
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/ELFeeRecipient.1.t.sol)

**Inherits:**
Test


## State Variables
### feeRecipient

```solidity
ELFeeRecipientV1 internal feeRecipient
```


### river

```solidity
RiverDonationMock internal river
```


### uf

```solidity
UserFactory internal uf = new UserFactory()
```


## Events
### BalanceUpdated

```solidity
event BalanceUpdated(uint256 amount);
```

### SetRiver

```solidity
event SetRiver(address indexed river);
```

