# CoverageFundTestV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/CoverageFund.1.t.sol)

**Inherits:**
[CoverageFundV1TestBase](/contracts/test/CoverageFund.1.t.sol/abstract.CoverageFundV1TestBase.md)


## Functions
### setUp


```solidity
function setUp() public;
```

### testTransferInvalidCall


```solidity
function testTransferInvalidCall(uint256 _senderSalt, uint256 _amount) external;
```

### testSendInvalidCall


```solidity
function testSendInvalidCall(uint256 _senderSalt, uint256 _amount) external;
```

### testCallInvalidCall


```solidity
function testCallInvalidCall(uint256 _senderSalt, uint256 _amount) external;
```

### testPullFundsFromDonate


```solidity
function testPullFundsFromDonate(uint256 _senderSalt, uint256 _amount) external;
```

### testPullHalfFundsFromDonate


```solidity
function testPullHalfFundsFromDonate(uint256 _senderSalt, uint256 _amount) external;
```

### testDonateUnauthorized


```solidity
function testDonateUnauthorized(uint256 _senderSalt, uint256 _amount) external;
```

### testDonateZero


```solidity
function testDonateZero(uint256 _senderSalt) external;
```

### testPullFundsUnauthorized


```solidity
function testPullFundsUnauthorized(uint256 _senderSalt, uint256 _amount) external;
```

### testFallbackFail


```solidity
function testFallbackFail() external;
```

### testNoFundPulled


```solidity
function testNoFundPulled() external;
```

### testVersion


```solidity
function testVersion() external;
```

