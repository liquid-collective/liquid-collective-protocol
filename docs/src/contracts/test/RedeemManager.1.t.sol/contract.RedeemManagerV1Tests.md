# RedeemManagerV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/RedeemManager.1.t.sol)

**Inherits:**
[RedeeManagerV1TestBase](/contracts/test/RedeemManager.1.t.sol/contract.RedeeManagerV1TestBase.md)


## State Variables
### redeemManager

```solidity
RedeemManagerV1 internal redeemManager
```


## Functions
### setUp


```solidity
function setUp() external;
```

### _allowlistUser


```solidity
function _allowlistUser(address user) internal;
```

### _generateAllowlistedUser


```solidity
function _generateAllowlistedUser(uint256 _salt) internal returns (address);
```

### _denyUser


```solidity
function _denyUser(address user) internal;
```

### _unDenyUser


```solidity
function _unDenyUser(address user) internal;
```

### testGetRiver


```solidity
function testGetRiver() public view;
```

### testRequestRedeem


```solidity
function testRequestRedeem(uint256 _salt) external;
```

### testRequestRedeemImplicitRecipient


```solidity
function testRequestRedeemImplicitRecipient(uint256 _salt) external;
```

### testRequestRedeemUnauthorizedUser


```solidity
function testRequestRedeemUnauthorizedUser(uint256 _salt) external;
```

### testRequestRedeemWithAuthorizedRecipient


```solidity
function testRequestRedeemWithAuthorizedRecipient(uint256 _salt, uint256 _salt2) external;
```

### testRequestRedeemUnauthorizedRecipient


```solidity
function testRequestRedeemUnauthorizedRecipient(uint256 _salt, uint256 _salt2) external;
```

### testRequestRedeemMultiple


```solidity
function testRequestRedeemMultiple(uint256 _salt) external;
```

### testRequestRedeemAmountZero


```solidity
function testRequestRedeemAmountZero(uint256 _salt) external;
```

### testRequestRedeemApproveTooLow


```solidity
function testRequestRedeemApproveTooLow(uint256 _salt) external;
```

### testRequestRedeemZeroRecipient


```solidity
function testRequestRedeemZeroRecipient(uint256 _salt) external;
```

### testReportWithdraw


```solidity
function testReportWithdraw(uint256 _salt) external;
```

### testReportWithdrawFail


```solidity
function testReportWithdrawFail(uint256 _salt) external;
```

### testReportWithdrawMultiple


```solidity
function testReportWithdrawMultiple(uint256 _salt) external;
```

### testClaimRedeemRequest


```solidity
function testClaimRedeemRequest(uint256 _salt) external;
```

### testClaimRedeemRequestWithImplicitSkipFlag


```solidity
function testClaimRedeemRequestWithImplicitSkipFlag(uint256 _salt) external;
```

### testClaimRedeemRequestTwiceWithSkipFlag


```solidity
function testClaimRedeemRequestTwiceWithSkipFlag(uint256 _salt) external;
```

### testClaimRedeemRequestTwiceWithoutSkipFlag


```solidity
function testClaimRedeemRequestTwiceWithoutSkipFlag(uint256 _salt) external;
```

### testClaimRedeemRequestsSkipDoesNotBreakSubsequentClaims


```solidity
function testClaimRedeemRequestsSkipDoesNotBreakSubsequentClaims(uint256 _salt) external;
```

### testClaimRedeemRequestTwiceBigger


```solidity
function testClaimRedeemRequestTwiceBigger(uint256 _salt) external;
```

### testClaimRedeemRequestOnMultipleEventsCustomDepths


```solidity
function testClaimRedeemRequestOnMultipleEventsCustomDepths(uint256 _salt) external;
```

### testClaimRedeemRequestOnTwoEvents


```solidity
function testClaimRedeemRequestOnTwoEvents(uint256 _salt) external;
```

### testClaimRedeemRequestTwoRequestsOnOneEvent


```solidity
function testClaimRedeemRequestTwoRequestsOnOneEvent(uint256 _salt) external;
```

### testClaimRedeemRequestIncompatibleArrayLengths


```solidity
function testClaimRedeemRequestIncompatibleArrayLengths(uint256 _salt) external;
```

### testClaimRedeemRequestOutOfBounds


```solidity
function testClaimRedeemRequestOutOfBounds() external;
```

### testClaimRedeemRequestWithdrawalEventOutOfBounds


```solidity
function testClaimRedeemRequestWithdrawalEventOutOfBounds(uint256 _salt) external;
```

### testClaimRedeemRequestNotMatching


```solidity
function testClaimRedeemRequestNotMatching(uint256 _salt) external;
```

### rollNext


```solidity
function rollNext(uint256 _salt) internal pure returns (uint256);
```

### testFillingBothQueues


```solidity
function testFillingBothQueues(uint256 _salt) external;
```

### applyRate


```solidity
function applyRate(uint256 amount, uint256 rate) internal pure returns (uint256);
```

### testClaimMultiRate


```solidity
function testClaimMultiRate() external;
```

### testResolveOutOfBounds


```solidity
function testResolveOutOfBounds() external;
```

### testResolveUnsatisfied


```solidity
function testResolveUnsatisfied(uint256 _salt) external;
```

### testResolveRedeemRequestForZeroIds


```solidity
function testResolveRedeemRequestForZeroIds() external;
```

### testPullExceedingEth


```solidity
function testPullExceedingEth() external;
```

### testClaimRedeemRequestFailsWithDeniedUser


```solidity
function testClaimRedeemRequestFailsWithDeniedUser(uint256 _salt) external;
```

### testClaimRedeemRequestFailsWithDeniedInitiator


```solidity
function testClaimRedeemRequestFailsWithDeniedInitiator(uint256 _salt, uint256 _salt2) external;
```

### testClaimRedeemRequestClaimsWithDeniedUserUndenied


```solidity
function testClaimRedeemRequestClaimsWithDeniedUserUndenied(uint256 _salt) external;
```

### testUnclaimableDeniedETHRemainsInProtocol


```solidity
function testUnclaimableDeniedETHRemainsInProtocol(uint256 _salt, uint256 _salt2) external;
```

### testClaimRedeemRequestEmitsClaimedEvent


```solidity
function testClaimRedeemRequestEmitsClaimedEvent(uint256 _salt) external;
```

### testClaimRedeemRequestRevertsOnFailedEtherTransferToRecipient


```solidity
function testClaimRedeemRequestRevertsOnFailedEtherTransferToRecipient(uint256 _salt) external;
```

### testVersion


```solidity
function testVersion() external;
```

