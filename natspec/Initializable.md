# Initializable

*Alluvial Finance Inc.*

> Initializable

This contract ensures that initializers are called only once per version




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


