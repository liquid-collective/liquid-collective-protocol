# ConsensusLayerDepositManagerV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ConsensusLayerDepositManager.1.t.sol)

**Inherits:**
[OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md)


## State Variables
### withdrawalCredentials

```solidity
bytes32 internal withdrawalCredentials = bytes32(uint256(1))
```


### depositManager

```solidity
ConsensusLayerDepositManagerV1 internal depositManager
```


### depositContract

```solidity
IDepositContract internal depositContract
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testRetrieveWithdrawalCredentials


```solidity
function testRetrieveWithdrawalCredentials() public view;
```

### testDepositNotEnoughFunds


```solidity
function testDepositNotEnoughFunds() public;
```

### testDepositTenValidators


```solidity
function testDepositTenValidators() public;
```

### testDepositLessThanMaxDepositableCount


```solidity
function testDepositLessThanMaxDepositableCount() public;
```

