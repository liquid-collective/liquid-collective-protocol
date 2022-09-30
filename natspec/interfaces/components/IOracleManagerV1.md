# IOracleManagerV1

*Kiln*

> Oracle Manager (v1)

This interface exposes methods to handle the inputs provided by the oracle



## Methods

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

### getOracle

```solidity
function getOracle() external view returns (address)
```

Get oracle address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The oracle address |

### setConsensusLayerData

```solidity
function setConsensusLayerData(uint256 _validatorCount, uint256 _validatorTotalBalance, bytes32 _roundId, uint256 _maxIncrease) external nonpayable
```

Sets the validator count and validator total balance sum reported by the oracle

*Can only be called by the oracle addressThe round id is a blackbox value that should only be used to identify unique reportsWhen a report is performed, River computes the amount of fees that can be pulledfrom the execution layer fee recipient. This amount is capped by the max allowedincrease provided during the report.If the total asset balance increases (from the reported total balance and the pulled funds)we then compute the share that must be taken for the collector on the positive delta.The execution layer fees are taken into account here because they are the product ofnode operator&#39;s work, just like consensus layer fees, and both should be handled in thesame manner, as a single revenue stream for the users and the collector.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _validatorCount | uint256 | The number of active validators on the consensus layer |
| _validatorTotalBalance | uint256 | The balance sum of the active validators on the consensus layer |
| _roundId | bytes32 | An identifier for this update |
| _maxIncrease | uint256 | The maximum allowed increase in the total balance |

### setOracle

```solidity
function setOracle(address _oracleAddress) external nonpayable
```

Set the oracle address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleAddress | address | Address of the oracle |



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

### SetOracle

```solidity
event SetOracle(address indexed oracleAddress)
```

The stored oracle address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| oracleAddress `indexed` | address | The new oracle address |



## Errors

### InvalidValidatorCountReport

```solidity
error InvalidValidatorCountReport(uint256 providedValidatorCount, uint256 depositedValidatorCount)
```

The reported validator count is invalid



#### Parameters

| Name | Type | Description |
|---|---|---|
| providedValidatorCount | uint256 | The received validator count value |
| depositedValidatorCount | uint256 | The number of deposits performed by the system |


