# IELFeeRecipientV1









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
function pullELFees() external nonpayable
```

Pulls all the ETH to the River contract

*Only callable by the River contract*




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

The fallback has been triggered with calldata





