# IELFeeRecipientV1

*Kiln*

> Execution Layer Fee Recipient Interface (v1)

This interface exposes methods to receive all the execution layer fees from the proposed blocks + bribes



## Methods

### initELFeeRecipientV1

```solidity
function initELFeeRecipientV1(address _riverAddress) external nonpayable
```

Initialize the fee recipient with the required arguments



#### Parameters

| Name | Type | Description |
|---|---|---|
| _riverAddress | address | Address of River |

### pullELFees

```solidity
function pullELFees(uint256 _maxAmount) external nonpayable
```

Pulls ETH to the River contract

*Only callable by the River contract*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxAmount | uint256 | The maximum amount to pull into the system |



## Events

### SetRiver

```solidity
event SetRiver(address indexed river)
```

The storage river address has changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| river `indexed` | address | The new river address |



## Errors

### InvalidCall

```solidity
error InvalidCall()
```

The fallback has been triggered





