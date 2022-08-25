# OracleManagerV1

*Kiln*

> Oracle Manager (v1)

This contract handles the inputs provided by the oracle



## Methods

### getBeaconValidatorBalanceSum

```solidity
function getBeaconValidatorBalanceSum() external view returns (uint256 beaconValidatorBalanceSum)
```

Get Beacon validator balance sum




#### Returns

| Name | Type | Description |
|---|---|---|
| beaconValidatorBalanceSum | uint256 | undefined |

### getBeaconValidatorCount

```solidity
function getBeaconValidatorCount() external view returns (uint256 beaconValidatorCount)
```

Get Beacon validator count (the amount of validator reported by the oracles)




#### Returns

| Name | Type | Description |
|---|---|---|
| beaconValidatorCount | uint256 | undefined |

### getOracle

```solidity
function getOracle() external view returns (address oracle)
```

Get Oracle address




#### Returns

| Name | Type | Description |
|---|---|---|
| oracle | address | undefined |

### setBeaconData

```solidity
function setBeaconData(uint256 _validatorCount, uint256 _validatorBalanceSum, bytes32 _roundId) external nonpayable
```

Sets the validator count and validator balance sum reported by the oracle

*Can only be called by the oracle address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _validatorCount | uint256 | The number of active validators on the consensus layer |
| _validatorBalanceSum | uint256 | The validator balance sum of the active validators on the consensus layer |
| _roundId | bytes32 | An identifier for this update |

### setOracle

```solidity
function setOracle(address _oracleAddress) external nonpayable
```

Set Oracle address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleAddress | address | Address of the oracle |



## Events

### BeaconDataUpdate

```solidity
event BeaconDataUpdate(uint256 validatorCount, uint256 validatorBalanceSum, bytes32 roundId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| validatorCount  | uint256 | undefined |
| validatorBalanceSum  | uint256 | undefined |
| roundId  | bytes32 | undefined |



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

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```






### Unauthorized

```solidity
error Unauthorized(address caller)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | undefined |


