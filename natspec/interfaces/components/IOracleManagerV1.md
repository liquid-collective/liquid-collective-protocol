# IOracleManagerV1









## Methods

### getCLValidatorCount

```solidity
function getCLValidatorCount() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getCLValidatorTotalBalance

```solidity
function getCLValidatorTotalBalance() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getOracle

```solidity
function getOracle() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### setConsensusLayerData

```solidity
function setConsensusLayerData(uint256 _validatorCount, uint256 _validatorTotalBalance, bytes32 _roundId) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _validatorCount | uint256 | undefined |
| _validatorTotalBalance | uint256 | undefined |
| _roundId | bytes32 | undefined |

### setOracle

```solidity
function setOracle(address _oracleAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleAddress | address | undefined |



## Events

### ConsensusLayerDataUpdate

```solidity
event ConsensusLayerDataUpdate(uint256 validatorCount, uint256 validatorTotalBalance, bytes32 roundId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| validatorCount  | uint256 | undefined |
| validatorTotalBalance  | uint256 | undefined |
| roundId  | bytes32 | undefined |

### SetOracle

```solidity
event SetOracle(address indexed oracleAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| oracleAddress `indexed` | address | undefined |



## Errors

### InvalidValidatorCountReport

```solidity
error InvalidValidatorCountReport(uint256 _providedValidatorCount, uint256 _depositedValidatorCount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _providedValidatorCount | uint256 | undefined |
| _depositedValidatorCount | uint256 | undefined |


