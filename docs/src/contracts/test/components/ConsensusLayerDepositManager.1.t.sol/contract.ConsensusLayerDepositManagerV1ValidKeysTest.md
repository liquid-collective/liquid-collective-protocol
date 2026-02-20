# ConsensusLayerDepositManagerV1ValidKeysTest
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
bytes32 internal withdrawalCredentials = bytes32(
    uint256(uint160(0xd74E967a7D771D7C6757eDb129229C3C8364A584))
        + 0x0100000000000000000000000000000000000000000000000000000000000000
)
```


### depositDataRoot

```solidity
bytes32 internal depositDataRoot = 0x306fbdcbdbb43ac873b85aea54b2035b10b3b28d55d3869fb499f0b7f7811247
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testDepositValidKey


```solidity
function testDepositValidKey() external;
```

### testDepositFailsWithInvalidDepositRoot


```solidity
function testDepositFailsWithInvalidDepositRoot() public;
```

