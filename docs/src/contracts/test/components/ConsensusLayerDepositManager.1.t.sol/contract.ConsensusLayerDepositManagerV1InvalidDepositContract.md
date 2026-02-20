# ConsensusLayerDepositManagerV1InvalidDepositContract
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ConsensusLayerDepositManager.1.t.sol)

**Inherits:**
[OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md)


## State Variables
### depositManager

```solidity
ConsensusLayerDepositManagerV1 internal depositManager
```


### depositContract

```solidity
IDepositContract internal depositContract
```


### withdrawalCredentials

```solidity
bytes32 internal withdrawalCredentials = bytes32(uint256(1))
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testDepositInvalidDepositContract


```solidity
function testDepositInvalidDepositContract() external;
```

