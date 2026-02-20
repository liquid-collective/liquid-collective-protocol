# OperatorsRegistryV1TestBase
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/OperatorsRegistry.1.t.sol)

**Inherits:**
Test


## State Variables
### uf

```solidity
UserFactory internal uf = new UserFactory()
```


### operatorsRegistry

```solidity
OperatorsRegistryV1 internal operatorsRegistry
```


### admin

```solidity
address internal admin
```


### river

```solidity
address internal river
```


### keeper

```solidity
address internal keeper
```


### firstName

```solidity
string internal firstName = "Operator One"
```


### secondName

```solidity
string internal secondName = "Operator Two"
```


## Events
### AddedValidatorKeys

```solidity
event AddedValidatorKeys(uint256 indexed index, bytes publicKeys);
```

### RemovedValidatorKey

```solidity
event RemovedValidatorKey(uint256 indexed index, bytes publicKey);
```

### SetRiver

```solidity
event SetRiver(address indexed river);
```

### OperatorLimitUnchanged

```solidity
event OperatorLimitUnchanged(uint256 indexed operatorIndex, uint256 limit);
```

### OperatorEditsAfterSnapshot

```solidity
event OperatorEditsAfterSnapshot(
    uint256 indexed index,
    uint256 currentLimit,
    uint256 newLimit,
    uint256 indexed lastEdit,
    uint256 indexed snapshotBlock
);
```

### SetOperatorLimit

```solidity
event SetOperatorLimit(uint256 indexed index, uint256 newLimit);
```

### AddedValidatorKeys

```solidity
event AddedValidatorKeys(uint256 indexed index, uint256 amount);
```

### UpdatedStoppedValidators

```solidity
event UpdatedStoppedValidators(uint32[] stoppedValidatorCounts);
```

### SetOperatorStoppedValidatorCount

```solidity
event SetOperatorStoppedValidatorCount(uint256 indexed index, uint256 newStoppedValidatorCount);
```

