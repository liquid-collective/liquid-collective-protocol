# IOracleManagerV1









## Methods

### getBeaconValidatorBalanceSum

```solidity
function getBeaconValidatorBalanceSum() external view returns (uint256 beaconValidatorBalanceSum)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| beaconValidatorBalanceSum | uint256 | undefined |

### getBeaconValidatorCount

```solidity
function getBeaconValidatorCount() external view returns (uint256 beaconValidatorCount)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| beaconValidatorCount | uint256 | undefined |

### getOracle

```solidity
function getOracle() external view returns (address oracle)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| oracle | address | undefined |

### setBeaconData

```solidity
function setBeaconData(uint256 _validatorCount, uint256 _validatorBalanceSum, bytes32 _roundId) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _validatorCount | uint256 | undefined |
| _validatorBalanceSum | uint256 | undefined |
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


