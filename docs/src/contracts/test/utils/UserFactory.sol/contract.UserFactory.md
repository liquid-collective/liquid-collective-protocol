# UserFactory
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/utils/UserFactory.sol)


## State Variables
### counter

```solidity
uint256 internal counter
```


## Functions
### _new


```solidity
function _new(uint256 _salt) public returns (address user);
```

### _newMulti


```solidity
function _newMulti(uint256 _salt, uint256 _count) external returns (address[] memory users);
```

