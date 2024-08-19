# ELFeeRecipientV1

*Alluvial Finance Inc.*

> Execution Layer Fee Recipient (v1)

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
function pullELFees(uint256 _maxAmount) external nonpayable
```

Pulls ETH to the River contract

*Only callable by the River contract*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxAmount | uint256 | The maximum amount to pull into the system |

### version

```solidity
function version() external pure returns (string)
```

Retrieves the version of the contract




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | Version of the contract |



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




### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Address performing the call |


