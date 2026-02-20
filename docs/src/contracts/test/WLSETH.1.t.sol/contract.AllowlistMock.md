# AllowlistMock
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/WLSETH.1.t.sol)


## State Variables
### denied

```solidity
mapping(address => bool) internal denied
```


## Functions
### isDenied


```solidity
function isDenied(address _account) external view returns (bool);
```

### sudoSetDenied


```solidity
function sudoSetDenied(address _account, bool _isDenied) external;
```

