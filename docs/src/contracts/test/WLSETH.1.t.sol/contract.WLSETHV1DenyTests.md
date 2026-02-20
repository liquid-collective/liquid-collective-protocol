# WLSETHV1DenyTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/WLSETH.1.t.sol)

**Inherits:**
[WLSETHV1TestBase](/contracts/test/WLSETH.1.t.sol/abstract.WLSETHV1TestBase.md)


## Functions
### setUp


```solidity
function setUp() external;
```

### _mint


```solidity
function _mint(address _who, uint256 _sum) internal;
```

### testTransferDeniedSender


```solidity
function testTransferDeniedSender(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external;
```

### testTransferDeniedRecipient


```solidity
function testTransferDeniedRecipient(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external;
```

### testTransferFromDeniedSender


```solidity
function testTransferFromDeniedSender(uint256 _fromSalt, uint256 _approvedSalt, uint256 _recipientSalt, uint32 _sum)
    external;
```

### testTransferFromDeniedRecipient


```solidity
function testTransferFromDeniedRecipient(
    uint256 _fromSalt,
    uint256 _approvedSalt,
    uint256 _recipientSalt,
    uint32 _sum
) external;
```

### testTransferSucceedsWhenNotDenied


```solidity
function testTransferSucceedsWhenNotDenied(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external;
```

### testTransferSucceedsAfterUndeny


```solidity
function testTransferSucceedsAfterUndeny(uint256 _guySalt, uint256 _recipientSalt, uint32 _sum) external;
```

