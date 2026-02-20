# CoverageFundV1TestBase
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/CoverageFund.1.t.sol)

**Inherits:**
Test


## State Variables
### coverageFund

```solidity
CoverageFundV1 internal coverageFund
```


### allowlist

```solidity
AllowlistV1 internal allowlist
```


### river

```solidity
RiverMock internal river
```


### uf

```solidity
UserFactory internal uf = new UserFactory()
```


### admin

```solidity
address internal admin
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

### Donate

```solidity
event Donate(address indexed donator, uint256 amount);
```

