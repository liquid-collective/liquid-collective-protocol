# ICoverageFundV1

*Kiln*

> Coverage Fund Interface (v1)

This interface exposes methods to receive donations for the slashing coverage fund and pull the funds into river



## Methods

### donate

```solidity
function donate() external payable
```

Donates ETH to the coverage fund contract




### initCoverageFundV1

```solidity
function initCoverageFundV1(address _riverAddress) external nonpayable
```

Initialize the coverage fund with the required arguments



#### Parameters

| Name | Type | Description |
|---|---|---|
| _riverAddress | address | Address of River |

### pullCoverageFunds

```solidity
function pullCoverageFunds(uint256 _maxAmount) external nonpayable
```

Pulls ETH into the River contract

*Only callable by the River contract*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxAmount | uint256 | The maximum amount to pull into the system |



## Events

### Donate

```solidity
event Donate(address indexed donator, uint256 amount)
```

A donation has been made to the coverage fund



#### Parameters

| Name | Type | Description |
|---|---|---|
| donator `indexed` | address | Address that performed the donation |
| amount  | uint256 | The amount donated |

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

### EmptyDonation

```solidity
error EmptyDonation()
```

A donation with 0 ETH has been performed




### InvalidCall

```solidity
error InvalidCall()
```

The fallback or receive callback has been triggered





