# UserDepositManagerV1DepositTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/UserDepositManager.1.t.sol)

**Inherits:**
Test


## State Variables
### transferManager

```solidity
UserDepositManagerV1 internal transferManager
```


### uf

```solidity
UserFactory internal uf = new UserFactory()
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testDepositWithDedicatedMethod


```solidity
function testDepositWithDedicatedMethod(uint256 _userSalt, uint256 _amount) public;
```

### testDepositToAnotherUserWithDedicatedMethod


```solidity
function testDepositToAnotherUserWithDedicatedMethod(uint256 _userSalt, uint256 _anotherUserSalt, uint256 _amount)
    public;
```

### testDepositWithReceiveFallback


```solidity
function testDepositWithReceiveFallback(uint256 _userSalt, uint256 _amount) public;
```

### testDepositWithCalldataFallback


```solidity
function testDepositWithCalldataFallback(uint256 _userSalt, uint256 _amount) public;
```

## Events
### UserDeposit

```solidity
event UserDeposit(address indexed depositor, address indexed recipient, uint256 amount);
```

### SetBalanceToDeposit

```solidity
event SetBalanceToDeposit(uint256 oldAmount, uint256 newAmount);
```

## Errors
### InvalidCall

```solidity
error InvalidCall();
```

