# UserDepositManagerV1CallbackTests
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

### testDepositInternalCallback


```solidity
function testDepositInternalCallback(uint256 _userSalt, uint256 _amount) public;
```

### testDepositToAnotherUserInternalCallback


```solidity
function testDepositToAnotherUserInternalCallback(uint256 _userSalt, uint256 _anotherUserSalt, uint256 _amount)
    public;
```

## Events
### InternalCallbackCalled

```solidity
event InternalCallbackCalled(address depositor, address recipient, uint256 amount);
```

