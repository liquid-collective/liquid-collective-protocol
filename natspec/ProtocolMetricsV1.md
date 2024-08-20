# ProtocolMetricsV1









## Methods

### getRate

```solidity
function getRate() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### initProtocolMetricsV1

```solidity
function initProtocolMetricsV1(address river) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| river | address | undefined |



## Events

### Initialize

```solidity
event Initialize(uint256 version, bytes cdata)
```

Emitted when the contract is properly initialized



#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint256 | New version of the contracts |
| cdata  | bytes | Complete calldata that was used during the initialization |



## Errors

### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```

An error occured during the initialization



#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | The version that was attempting to be initialized |
| expectedVersion | uint256 | The version that was expected |

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero





