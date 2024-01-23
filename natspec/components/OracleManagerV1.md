# OracleManagerV1

*Kiln*

> Oracle Manager (v1)

This contract handles the inputs provided by the oracleThe Oracle contract is plugged to this contract and is in charge of pushingdata whenever a new report has been deemed valid. The report consists in twovalues: the sum of all balances of all deposited validators and the count ofvalidators that have been activated on the consensus layer.



## Methods

### _DEPOSIT_SIZE

```solidity
function _DEPOSIT_SIZE() external view returns (uint256)
```

Size of a deposit in ETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getCLSpec

```solidity
function getCLSpec() external view returns (struct CLSpec.CLSpecStruct)
```

Retrieve the current cl spec




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | CLSpec.CLSpecStruct | The Consensus Layer Specification |

### getCLValidatorCount

```solidity
function getCLValidatorCount() external view returns (uint256)
```

Get CL validator count (the amount of validator reported by the oracles)




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The CL validator count |

### getCLValidatorTotalBalance

```solidity
function getCLValidatorTotalBalance() external view returns (uint256)
```

Get CL validator total balance




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The CL Validator total balance |

### getCurrentEpochId

```solidity
function getCurrentEpochId() external view returns (uint256)
```

Retrieve the current epoch id based on block timestamp




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current epoch id |

### getCurrentFrame

```solidity
function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime)
```

Retrieve the current frame details




#### Returns

| Name | Type | Description |
|---|---|---|
| _startEpochId | uint256 | The epoch at the beginning of the frame |
| _startTime | uint256 | The timestamp of the beginning of the frame in seconds |
| _endTime | uint256 | The timestamp of the end of the frame in seconds |

### getExpectedEpochId

```solidity
function getExpectedEpochId() external view returns (uint256)
```

Retrieve expected epoch id




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current expected epoch id |

### getFrameFirstEpochId

```solidity
function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256)
```

Retrieve the first epoch id of the frame of the provided epoch id



#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId | uint256 | Epoch id used to get the frame |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The first epoch id of the frame containing the given epoch id |

### getLastCompletedEpochId

```solidity
function getLastCompletedEpochId() external view returns (uint256)
```

Retrieve the last completed epoch id




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The last completed epoch id |

### getLastConsensusLayerReport

```solidity
function getLastConsensusLayerReport() external view returns (struct IOracleManagerV1.StoredConsensusLayerReport)
```

Retrieve the last consensus layer report




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | IOracleManagerV1.StoredConsensusLayerReport | The stored consensus layer report |

### getOracle

```solidity
function getOracle() external view returns (address)
```

Get oracle address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The oracle address |

### getReportBounds

```solidity
function getReportBounds() external view returns (struct ReportBounds.ReportBoundsStruct)
```

Retrieve the report bounds




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | ReportBounds.ReportBoundsStruct | The report bounds |

### getTime

```solidity
function getTime() external view returns (uint256)
```

Retrieve the block timestamp




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current timestamp from the EVM context |

### isValidEpoch

```solidity
function isValidEpoch(uint256 _epoch) external view returns (bool)
```

Verifies if the provided epoch is valid



#### Parameters

| Name | Type | Description |
|---|---|---|
| _epoch | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if valid |

### setCLSpec

```solidity
function setCLSpec(CLSpec.CLSpecStruct _newValue) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newValue | CLSpec.CLSpecStruct | undefined |

### setConsensusLayerData

```solidity
function setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport _report) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _report | IOracleManagerV1.ConsensusLayerReport | undefined |

### setOracle

```solidity
function setOracle(address _oracleAddress) external nonpayable
```

Set the oracle address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleAddress | address | Address of the oracle |

### setReportBounds

```solidity
function setReportBounds(ReportBounds.ReportBoundsStruct _newValue) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newValue | ReportBounds.ReportBoundsStruct | undefined |



## Events

### ConsensusLayerDataUpdate

```solidity
event ConsensusLayerDataUpdate(uint256 validatorCount, uint256 validatorTotalBalance, bytes32 roundId)
```

The consensus layer data provided by the oracle has been updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| validatorCount  | uint256 | The new count of validators running on the consensus layer |
| validatorTotalBalance  | uint256 | The new total balance sum of all validators |
| roundId  | bytes32 | Round identifier |

### ProcessedConsensusLayerReport

```solidity
event ProcessedConsensusLayerReport(IOracleManagerV1.ConsensusLayerReport report, IOracleManagerV1.ConsensusLayerDataReportingTrace trace)
```

The provided report has beend processed



#### Parameters

| Name | Type | Description |
|---|---|---|
| report  | IOracleManagerV1.ConsensusLayerReport | The report that was provided |
| trace  | IOracleManagerV1.ConsensusLayerDataReportingTrace | The trace structure providing more insights on internals |

### SetBounds

```solidity
event SetBounds(uint256 annualAprUpperBound, uint256 relativeLowerBound)
```

The Report Bounds are changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| annualAprUpperBound  | uint256 | The reporting upper bound |
| relativeLowerBound  | uint256 | The reporting lower bound |

### SetOracle

```solidity
event SetOracle(address indexed oracleAddress)
```

The stored oracle address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| oracleAddress `indexed` | address | The new oracle address |

### SetSpec

```solidity
event SetSpec(uint64 epochsPerFrame, uint64 slotsPerEpoch, uint64 secondsPerSlot, uint64 genesisTime, uint64 epochsToAssumedFinality)
```

The Consensus Layer Spec is changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| epochsPerFrame  | uint64 | The number of epochs inside a frame |
| slotsPerEpoch  | uint64 | The number of slots inside an epoch |
| secondsPerSlot  | uint64 | The number of seconds inside a slot |
| genesisTime  | uint64 | The genesis timestamp |
| epochsToAssumedFinality  | uint64 | The number of epochs before an epoch is considered final |



## Errors

### InvalidDecreasingValidatorsExitedBalance

```solidity
error InvalidDecreasingValidatorsExitedBalance(uint256 currentValidatorsExitedBalance, uint256 newValidatorsExitedBalance)
```

The total exited balance decreased



#### Parameters

| Name | Type | Description |
|---|---|---|
| currentValidatorsExitedBalance | uint256 | The current exited balance |
| newValidatorsExitedBalance | uint256 | The new exited balance |

### InvalidDecreasingValidatorsSkimmedBalance

```solidity
error InvalidDecreasingValidatorsSkimmedBalance(uint256 currentValidatorsSkimmedBalance, uint256 newValidatorsSkimmedBalance)
```

The total skimmed balance decreased



#### Parameters

| Name | Type | Description |
|---|---|---|
| currentValidatorsSkimmedBalance | uint256 | The current exited balance |
| newValidatorsSkimmedBalance | uint256 | The new exited balance |

### InvalidEpoch

```solidity
error InvalidEpoch(uint256 epoch)
```

Thrown when an invalid epoch was reported



#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch | uint256 | Invalid epoch |

### InvalidValidatorCountReport

```solidity
error InvalidValidatorCountReport(uint256 providedValidatorCount, uint256 depositedValidatorCount, uint256 lastReportedValidatorCount)
```

The reported validator count is invalid



#### Parameters

| Name | Type | Description |
|---|---|---|
| providedValidatorCount | uint256 | The received validator count value |
| depositedValidatorCount | uint256 | The number of deposits performed by the system |
| lastReportedValidatorCount | uint256 | The last reported validator count |

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero




### TotalValidatorBalanceDecreaseOutOfBound

```solidity
error TotalValidatorBalanceDecreaseOutOfBound(uint256 prevTotalEthIncludingExited, uint256 postTotalEthIncludingExited, uint256 timeElapsed, uint256 relativeLowerBound)
```

The balance decrease is higher than the maximum allowed by the lower bound



#### Parameters

| Name | Type | Description |
|---|---|---|
| prevTotalEthIncludingExited | uint256 | The previous total balance, including all exited balance |
| postTotalEthIncludingExited | uint256 | The post-report total balance, including all exited balance |
| timeElapsed | uint256 | The time in seconds since last report |
| relativeLowerBound | uint256 | The lower bound value that was used |

### TotalValidatorBalanceIncreaseOutOfBound

```solidity
error TotalValidatorBalanceIncreaseOutOfBound(uint256 prevTotalEthIncludingExited, uint256 postTotalEthIncludingExited, uint256 timeElapsed, uint256 annualAprUpperBound)
```

The balance increase is higher than the maximum allowed by the upper bound



#### Parameters

| Name | Type | Description |
|---|---|---|
| prevTotalEthIncludingExited | uint256 | The previous total balance, including all exited balance |
| postTotalEthIncludingExited | uint256 | The post-report total balance, including all exited balance |
| timeElapsed | uint256 | The time in seconds since last report |
| annualAprUpperBound | uint256 | The upper bound value that was used |

### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Address performing the call |


