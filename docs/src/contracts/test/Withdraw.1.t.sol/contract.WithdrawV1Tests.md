# WithdrawV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/Withdraw.1.t.sol)

**Inherits:**
[WithdrawV1TestBase](/contracts/test/Withdraw.1.t.sol/abstract.WithdrawV1TestBase.md)


## Functions
### setUp


```solidity
function setUp() public override;
```

### testReinitialize


```solidity
function testReinitialize() external;
```

### testGetCredentials


```solidity
function testGetCredentials() external;
```

### testGetRiver


```solidity
function testGetRiver() external;
```

### testPullFundsAsRiverPullAll


```solidity
function testPullFundsAsRiverPullAll(uint256 _amount) external;
```

### testSendingFundsReverting


```solidity
function testSendingFundsReverting(uint256 _amount) external;
```

### testPullFundsAsRiverPullPartial


```solidity
function testPullFundsAsRiverPullPartial(uint256 _salt, uint256 _amount) external;
```

### testPullFundsAsRandom


```solidity
function testPullFundsAsRandom(uint256 _salt) external;
```

### testPullFundsAsRiver


```solidity
function testPullFundsAsRiver() external;
```

### testPullFundsAmountTooHigh


```solidity
function testPullFundsAmountTooHigh(uint256 _amount) external;
```

### testNoFundPulled


```solidity
function testNoFundPulled() external;
```

### testVersion


```solidity
function testVersion() external;
```

