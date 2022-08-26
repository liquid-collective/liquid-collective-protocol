# ELFeeRecipientV1

*Kiln*

> Execution Layer Fee Recipient

This contract receives all the execution layer fees from the proposed blocks + bribes



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





## Errors

### InvalidCall

```solidity
error InvalidCall()
```






### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | undefined |
| expectedVersion | uint256 | undefined |

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


