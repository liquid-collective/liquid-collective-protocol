# RiverMock
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/OperatorsRegistry.1.t.sol)


## State Variables
### getDepositedValidatorCount

```solidity
uint256 public getDepositedValidatorCount
```


### keeper

```solidity
address public keeper
```


## Functions
### constructor


```solidity
constructor(uint256 _getDepositedValidatorsCount) ;
```

### sudoSetDepositedValidatorsCount


```solidity
function sudoSetDepositedValidatorsCount(uint256 _getDepositedValidatorsCount) external;
```

### setKeeper


```solidity
function setKeeper(address _keeper) external;
```

### getKeeper


```solidity
function getKeeper() external view returns (address);
```

