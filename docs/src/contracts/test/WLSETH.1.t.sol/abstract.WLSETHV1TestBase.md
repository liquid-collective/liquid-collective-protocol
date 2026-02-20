# WLSETHV1TestBase
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/WLSETH.1.t.sol)

**Inherits:**
Test


## State Variables
### river

```solidity
IRiverV1 internal river
```


### wlseth

```solidity
WLSETHV1 internal wlseth
```


### allowlistMock

```solidity
AllowlistMock internal allowlistMock
```


### uf

```solidity
UserFactory internal uf = new UserFactory()
```


## Events
### Mint

```solidity
event Mint(address indexed _recipient, uint256 _value);
```

### Burn

```solidity
event Burn(address indexed _recipient, uint256 _value);
```

### SetRiver

```solidity
event SetRiver(address indexed river);
```

### Transfer

```solidity
event Transfer(address indexed _from, address indexed _to, uint256 _value);
```

