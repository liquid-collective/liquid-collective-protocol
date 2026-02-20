# AllowlistV1TestBase
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/Allowlist.1.t.sol)

**Inherits:**
Test


## State Variables
### uf

```solidity
UserFactory internal uf = new UserFactory()
```


### withdrawalCredentials

```solidity
bytes32 internal withdrawalCredentials = bytes32(uint256(1))
```


### testAdmin

```solidity
address internal testAdmin = address(0xFA674fDde714fD979DE3EdF0f56aa9716b898eC8)
```


### allower

```solidity
address internal allower = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8)
```


### denier

```solidity
address internal denier = makeAddr("denier")
```


### allowlist

```solidity
AllowlistV1 internal allowlist
```


## Events
### SetAllower

```solidity
event SetAllower(address indexed allower);
```

### SetDenier

```solidity
event SetDenier(address indexed denier);
```

### SetAllowlistPermissions

```solidity
event SetAllowlistPermissions(address[] accounts, uint256[] permissions);
```

