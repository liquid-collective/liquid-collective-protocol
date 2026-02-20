# RiverMock
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/mocks/RiverMock.sol)


## State Variables
### validatorCount

```solidity
uint256 public validatorCount
```


### validatorBalanceSum

```solidity
uint256 public validatorBalanceSum
```


### _totalSupply

```solidity
uint256 internal _totalSupply
```


### _totalShares

```solidity
uint256 internal _totalShares
```


### invalidEpochs

```solidity
mapping(uint256 => bool) invalidEpochs
```


## Functions
### setConsensusLayerData


```solidity
function setConsensusLayerData(
    uint256 _validatorCount,
    uint256 _validatorBalanceSum,
    bytes32 _roundId,
    uint256 _maxIncrease
) external;
```

### sudoSetTotalSupply


```solidity
function sudoSetTotalSupply(uint256 _newTotalSupply) external;
```

### sudoSetTotalShares


```solidity
function sudoSetTotalShares(uint256 _newTotalShares) external;
```

### totalUnderlyingSupply


```solidity
function totalUnderlyingSupply() external view returns (uint256);
```

### totalSupply


```solidity
function totalSupply() external view returns (uint256);
```

### isValidEpoch


```solidity
function isValidEpoch(uint256 epoch) external view returns (bool);
```

### sudoSetInvalidEpoch


```solidity
function sudoSetInvalidEpoch(uint256 epoch) external;
```

### setConsensusLayerData


```solidity
function setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport calldata report) external;
```

## Events
### DebugReceivedCLData

```solidity
event DebugReceivedCLData(
    uint256 _validatorCount, uint256 _validatorBalanceSum, bytes32 _roundId, uint256 _maxIncrease
);
```

### DebugReceivedReport

```solidity
event DebugReceivedReport(IOracleManagerV1.ConsensusLayerReport report);
```

