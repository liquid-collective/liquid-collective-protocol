# SharesManagerV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/SharesManager.1.t.sol)

**Inherits:**
Test


## State Variables
### uf

```solidity
UserFactory internal uf = new UserFactory()
```


### sharesManager

```solidity
SharesManagerV1 internal sharesManager
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testBalanceOfUnderlying


```solidity
function testBalanceOfUnderlying(uint256 _userSalt) public;
```

### testUnderlyingBalanceFromShares


```solidity
function testUnderlyingBalanceFromShares(uint256 _userSalt) public;
```

### testBalanceOf


```solidity
function testBalanceOf(uint256 _userSalt, uint256 _anotherUserSalt) public;
```

### testBalanceOfMultiRebasings


```solidity
function testBalanceOfMultiRebasings(uint256 _userSalt, uint256 _anotherUserSalt) public;
```

### testTotalSupplyEvent


```solidity
function testTotalSupplyEvent(uint256 _userSalt, uint256 _anotherUserSalt) public;
```

### testName


```solidity
function testName() public view;
```

### testSymbol


```solidity
function testSymbol() public view;
```

### testDecimals


```solidity
function testDecimals() public view;
```

### testTotalSupply


```solidity
function testTotalSupply(uint256 _userSalt, uint128 validatorBalanceSum, uint128 depositSize) public;
```

### testApprove


```solidity
function testApprove(uint256 _userOneSalt, uint256 _userTwoSalt, uint256 _allowance) public;
```

### testApproveZeroAddress


```solidity
function testApproveZeroAddress(uint256 _userOneSalt, uint256 _allowance) public;
```

### testApproveAndTransferPartial


```solidity
function testApproveAndTransferPartial(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testApproveAndTransferTotal


```solidity
function testApproveAndTransferTotal(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testApproveAndTransferZero


```solidity
function testApproveAndTransferZero(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testApproveAndTransferAboveAllowance


```solidity
function testApproveAndTransferAboveAllowance(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
    public;
```

### testApproveAndTransferAboveBalance


```solidity
function testApproveAndTransferAboveBalance(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testApproveAndTransferUnauthorized


```solidity
function testApproveAndTransferUnauthorized(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testTransferPartial


```solidity
function testTransferPartial(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testTransferZeroAddress


```solidity
function testTransferZeroAddress(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testTransferTotal


```solidity
function testTransferTotal(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testApproveAndTransferMsgSender


```solidity
function testApproveAndTransferMsgSender(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testApproveAndTransferZeroAddress


```solidity
function testApproveAndTransferZeroAddress(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testIncreaseAllowanceAndTransferFrom


```solidity
function testIncreaseAllowanceAndTransferFrom(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
    public;
```

### testIncreaseDecreaseAllowanceAndTransferFrom


```solidity
function testIncreaseDecreaseAllowanceAndTransferFrom(
    uint256 _userOneSalt,
    uint256 _userTwoSalt,
    uint128 _allowance
) public;
```

### testApproveAndTransferUnauthorizedSender


```solidity
function testApproveAndTransferUnauthorizedSender(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
    public;
```

### testApproveAndTransferUnauthorizedReceiver


```solidity
function testApproveAndTransferUnauthorizedReceiver(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
    public;
```

### testTransferUnauthorizedSender


```solidity
function testTransferUnauthorizedSender(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testTransferUnauthorizedReceiver


```solidity
function testTransferUnauthorizedReceiver(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testTransferTransferZero


```solidity
function testTransferTransferZero(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public;
```

### testTransferTransferBalanceTooLow


```solidity
function testTransferTransferBalanceTooLow(uint256 _userOneSalt, uint256 _userTwoSalt) public;
```

### testExternalViewFunctions


```solidity
function testExternalViewFunctions() external;
```

## Events
### SetTotalSupply

```solidity
event SetTotalSupply(uint256 totalSupply);
```

## Errors
### Denied

```solidity
error Denied(address _account);
```

