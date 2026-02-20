# ELFeeRecipientV1Test
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/ELFeeRecipient.1.t.sol)

**Inherits:**
[ELFeeRecipientV1TestBase](/contracts/test/ELFeeRecipient.1.t.sol/abstract.ELFeeRecipientV1TestBase.md)


## Functions
### setUp


```solidity
function setUp() public;
```

### testPullFundsFromTransfer


```solidity
function testPullFundsFromTransfer(uint256 _senderSalt, uint256 _amount) external;
```

### testPullFundsFromSend


```solidity
function testPullFundsFromSend(uint256 _senderSalt, uint256 _amount) external;
```

### testPullFundsFromCall


```solidity
function testPullFundsFromCall(uint256 _senderSalt, uint256 _amount) external;
```

### testPullHalfFunds


```solidity
function testPullHalfFunds(uint256 _senderSalt, uint256 _amount) external;
```

### testNoFundPulled


```solidity
function testNoFundPulled() external;
```

### testPullFundsUnauthorized


```solidity
function testPullFundsUnauthorized(uint256 _senderSalt, uint256 _amount) external;
```

### testFallbackFail


```solidity
function testFallbackFail() external;
```

### testVersion


```solidity
function testVersion() external;
```

