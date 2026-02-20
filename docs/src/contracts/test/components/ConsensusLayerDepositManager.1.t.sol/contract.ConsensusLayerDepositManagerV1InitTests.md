# ConsensusLayerDepositManagerV1InitTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ConsensusLayerDepositManager.1.t.sol)

**Inherits:**
Test


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
### testDepositContractEvent


```solidity
function testDepositContractEvent() public;
```

### testWithdrawalCredentialsEvent


```solidity
function testWithdrawalCredentialsEvent() public;
```

## Events
### SetDepositContractAddress

```solidity
event SetDepositContractAddress(address indexed depositContract);
```

### SetWithdrawalCredentials

```solidity
event SetWithdrawalCredentials(bytes32 withdrawalCredentials);
```

