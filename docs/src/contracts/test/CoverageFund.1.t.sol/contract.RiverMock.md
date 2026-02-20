# RiverMock
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/CoverageFund.1.t.sol)


## State Variables
### allowlist

```solidity
address internal allowlist
```


## Functions
### constructor


```solidity
constructor(address _allowlist) ;
```

### sendCoverageFunds


```solidity
function sendCoverageFunds() external payable;
```

### pullCoverageFunds


```solidity
function pullCoverageFunds(address coverageFund, uint256 maxAmount) external;
```

### getAllowlist


```solidity
function getAllowlist() external view returns (address);
```

## Events
### BalanceUpdated

```solidity
event BalanceUpdated(uint256 amount);
```

