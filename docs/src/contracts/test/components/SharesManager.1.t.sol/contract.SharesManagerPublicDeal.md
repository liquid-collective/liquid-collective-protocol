# SharesManagerPublicDeal
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/SharesManager.1.t.sol)

**Inherits:**
[SharesManagerV1](/contracts/src/components/SharesManager.1.sol/abstract.SharesManagerV1.md)


## State Variables
### totalBalance

```solidity
uint256 public totalBalance
```


### denied

```solidity
mapping(address => bool) internal denied
```


## Functions
### setDenied


```solidity
function setDenied(address _account) external;
```

### _onTransfer


```solidity
function _onTransfer(address _from, address _to) internal view override;
```

### setValidatorBalance


```solidity
function setValidatorBalance(uint256 _amount) external;
```

### _assetBalance


```solidity
function _assetBalance() internal view override returns (uint256);
```

### deal


```solidity
function deal(address _owner, uint256 _amount) external;
```

### mint


```solidity
function mint(address _owner, uint256 _amount) external;
```

### fallback


```solidity
fallback() external payable;
```

### receive


```solidity
receive() external payable;
```

## Errors
### Denied

```solidity
error Denied(address _account);
```

