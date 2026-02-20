# RiverV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/River.1.t.sol)

**Inherits:**
[RiverV1TestBase](/contracts/test/River.1.t.sol/abstract.RiverV1TestBase.md)


## Functions
### setUp


```solidity
function setUp() public override;
```

### testVersion


```solidity
function testVersion() external;
```

### testOnlyAdminCanSetKeeper


```solidity
function testOnlyAdminCanSetKeeper() public;
```

### testInitWithZeroAddressValue


```solidity
function testInitWithZeroAddressValue() public;
```

### testAdditionalInit


```solidity
function testAdditionalInit() public;
```

### testInit2


```solidity
function testInit2(uint128 depositTotal, uint96 committedBalance) public;
```

### testSetDailyCommittableLimits


```solidity
function testSetDailyCommittableLimits(uint128 net, uint128 relative) public;
```

### testSetDailyCommittableLimitsUnauthorized


```solidity
function testSetDailyCommittableLimitsUnauthorized(uint128 net, uint128 relative) public;
```

### testSetELFeeRecipient


```solidity
function testSetELFeeRecipient(uint256 _newELFeeRecipientSalt) public;
```

### testSetELFeeRecipientUnauthorized


```solidity
function testSetELFeeRecipientUnauthorized(uint256 _newELFeeRecipientSalt) public;
```

### testSendCLFunds


```solidity
function testSendCLFunds(uint256 amount) public;
```

### testSendCLFundsUnauthorized


```solidity
function testSendCLFundsUnauthorized(uint256 _invalidAddressSalt) public;
```

### testSendELFundsUnauthorized


```solidity
function testSendELFundsUnauthorized(uint256 _invalidAddressSalt) public;
```

### testSetELFeeRecipientZero


```solidity
function testSetELFeeRecipientZero() public;
```

### testSetCoverageFund


```solidity
function testSetCoverageFund(uint256 _newCoverageFundSalt) public;
```

### testSetCoverageFundUnauthorized


```solidity
function testSetCoverageFundUnauthorized(uint256 _newCoverageFundSalt) public;
```

### testSetCoverageFundZero


```solidity
function testSetCoverageFundZero() public;
```

### testSendCoverageFundsUnauthorized


```solidity
function testSendCoverageFundsUnauthorized(uint256 _invalidAddressSalt) public;
```

### testGetOperatorsRegistry


```solidity
function testGetOperatorsRegistry() public view;
```

### testSetCollector


```solidity
function testSetCollector() public;
```

### testSetCollectorUnauthorized


```solidity
function testSetCollectorUnauthorized() public;
```

### testSetAllowlist


```solidity
function testSetAllowlist() public;
```

### testSetAllowlistUnauthorized


```solidity
function testSetAllowlistUnauthorized() public;
```

### testSetGlobalFee


```solidity
function testSetGlobalFee() public;
```

### testSetGlobalFeeHigherThanBase


```solidity
function testSetGlobalFeeHigherThanBase() public;
```

### testSetGlobalFeeUnauthorized


```solidity
function testSetGlobalFeeUnauthorized() public;
```

### testGetAdministrator


```solidity
function testGetAdministrator() public;
```

### testSetMetadataURI


```solidity
function testSetMetadataURI(string memory _metadataURI) public;
```

### testSetMetadataURIEmpty


```solidity
function testSetMetadataURIEmpty() public;
```

### testSetMetadataURIUnauthorized


```solidity
function testSetMetadataURIUnauthorized(string memory _metadataURI, uint256 _salt) public;
```

### _rawPermissions


```solidity
function _rawPermissions(address _who, uint256 _mask) internal;
```

### _allow


```solidity
function _allow(address _who) internal;
```

### _deny


```solidity
function _deny(address _who, bool _status) internal;
```

### testUnauthorizedDeposit


```solidity
function testUnauthorizedDeposit() public;
```

### testUserDeposits


```solidity
function testUserDeposits() public;
```

### testUserDepositsForAnotherUser


```solidity
function testUserDepositsForAnotherUser() public;
```

### testDeniedUser


```solidity
function testDeniedUser() public;
```

### testOnTransferFailsForAllowlistDenied


```solidity
function testOnTransferFailsForAllowlistDenied() public;
```

### testUserDepositsFullAllowance


```solidity
function testUserDepositsFullAllowance() public;
```

### testUserDepositsUnconventionalDeposits


```solidity
function testUserDepositsUnconventionalDeposits() public;
```

### testUserDepositsOperatorWithStoppedValidators


```solidity
function testUserDepositsOperatorWithStoppedValidators() public;
```

### _debugMaxIncrease


```solidity
function _debugMaxIncrease(uint256 annualAprUpperBound, uint256 _prevTotalEth, uint256 _timeElapsed)
    internal
    pure
    returns (uint256);
```

### testSendRedeemManagerUnauthorizedCall


```solidity
function testSendRedeemManagerUnauthorizedCall() public;
```

## Events
### SetMaxDailyCommittableAmounts

```solidity
event SetMaxDailyCommittableAmounts(uint256 maxNetAmount, uint256 maxRelativeAmount);
```

### SetMetadataURI

```solidity
event SetMetadataURI(string metadataURI);
```

