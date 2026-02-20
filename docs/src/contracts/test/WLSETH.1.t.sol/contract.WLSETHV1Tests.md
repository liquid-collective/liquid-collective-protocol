# WLSETHV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/WLSETH.1.t.sol)

**Inherits:**
[WLSETHV1TestBase](/contracts/test/WLSETH.1.t.sol/abstract.WLSETHV1TestBase.md)


## Functions
### setUp


```solidity
function setUp() external;
```

### testAlreadyInitialized


```solidity
function testAlreadyInitialized() external;
```

### testTokenName


```solidity
function testTokenName() external view;
```

### testTokenSymbol


```solidity
function testTokenSymbol() external view;
```

### testTokenDecimals


```solidity
function testTokenDecimals() external view;
```

### testTotalSupplyEdits


```solidity
function testTotalSupplyEdits(uint256 _guySalt, uint32 _sum) external;
```

### testTotalSupplyEditsMultiBurnsAndRebase


```solidity
function testTotalSupplyEditsMultiBurnsAndRebase(uint256 _guySalt) external;
```

### testBalanceOfEdits


```solidity
function testBalanceOfEdits(uint256 _guySalt, uint32 _sum) external;
```

### testBalanceOfEditsMultiBurnsAndRebase


```solidity
function testBalanceOfEditsMultiBurnsAndRebase(uint256 _guySalt) external;
```

### testBalanceOfEditsMultiBurnsMultiUserAndRebase


```solidity
function testBalanceOfEditsMultiBurnsMultiUserAndRebase(uint256 _guySalt, uint256 _otherGuySalt) external;
```

### testMintWrappedTokens


```solidity
function testMintWrappedTokens(uint256 _guySalt, uint32 _sum) external;
```

### testMintWrappedTokensCheckTransfer


```solidity
function testMintWrappedTokensCheckTransfer(uint256 _guySalt, uint32 _sum) external;
```

### testMintWrappedTokensInvalidTransfer


```solidity
function testMintWrappedTokensInvalidTransfer(uint256 _guySalt, uint32 _sum) external;
```

### _mint


```solidity
function _mint(address _who, uint256 _sum) internal;
```

### testTransfer


```solidity
function testTransfer(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external;
```

### testTransferFromMsgSender


```solidity
function testTransferFromMsgSender(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external;
```

### testTransferZero


```solidity
function testTransferZero(uint256 _guySalt, uint32 _sum) external;
```

### testTransferTooMuch


```solidity
function testTransferTooMuch(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external;
```

### testApprove


```solidity
function testApprove(uint256 _fromSalt, uint256 _approvedSalt, uint32 _sum) external;
```

### testApproveZero


```solidity
function testApproveZero(uint256 _fromSalt, uint32 _sum) external;
```

### testTransferFrom


```solidity
function testTransferFrom(uint256 _fromSalt, uint256 _approvedSalt, uint256 _recipientSalt, uint32 _sum) external;
```

### testTransferFromToZeroAddress


```solidity
function testTransferFromToZeroAddress(
    uint256 _fromSalt,
    uint256 _approvedSalt,
    uint256 _recipientSalt,
    uint32 _sum
) external;
```

### testTransferFromUnlimitedAllowance


```solidity
function testTransferFromUnlimitedAllowance(
    uint256 _fromSalt,
    uint256 _approvedSalt,
    uint256 _recipientSalt,
    uint32 _sum
) external;
```

### testTransferFromAfterIncreasedAllowance


```solidity
function testTransferFromAfterIncreasedAllowance(
    uint256 _fromSalt,
    uint256 _approvedSalt,
    uint256 _recipientSalt,
    uint32 _sum
) external;
```

### testTransferFromAfterIncreasedAndDecreasedAllowance


```solidity
function testTransferFromAfterIncreasedAndDecreasedAllowance(
    uint256 _fromSalt,
    uint256 _approvedSalt,
    uint256 _recipientSalt,
    uint32 _sum
) external;
```

### testTransferFromTooMuch


```solidity
function testTransferFromTooMuch(uint256 _fromSalt, uint256 _approvedSalt, uint256 _recipientSalt, uint32 _sum)
    external;
```

### testTransferFromApprovalTooLow


```solidity
function testTransferFromApprovalTooLow(
    uint256 _fromSalt,
    uint256 _approvedSalt,
    uint256 _recipientSalt,
    uint32 _sum
) external;
```

### testBurnWrappedTokensInvalidTransfer


```solidity
function testBurnWrappedTokensInvalidTransfer(uint256 _guySalt, uint32 _sum) external;
```

### testBurnWrappedTokens


```solidity
function testBurnWrappedTokens(uint256 _guySalt, uint32 _sum) external;
```

### testBurnWrappedTokensCheckTransfer


```solidity
function testBurnWrappedTokensCheckTransfer(uint256 _guySalt, uint32 _sum) external;
```

### testBurnWrappedTokensWithRebase


```solidity
function testBurnWrappedTokensWithRebase(uint256 _guySalt, uint32 _sum) external;
```

### testBurnFail


```solidity
function testBurnFail() external;
```

### testMintWrappedTokensTooMuch


```solidity
function testMintWrappedTokensTooMuch(uint256 _guySalt, uint32 _sum) external;
```

