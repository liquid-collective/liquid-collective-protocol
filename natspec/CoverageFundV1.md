# CoverageFundV1

*Kiln*

> Coverage Fund (v1)

This contract receive donations for the slashing coverage fund and pull the funds into riverThis contract acts as a temporary buffer for funds that should be pulled in case of a loss of money on the consensus layer due to slashing events.There is no fee taken on these funds, they are entirely distributed to the LsETH holders, and no shares will get minted.Funds will be distributed by increasing the underlying value of every LsETH share.The fund will be called on every report and if eth is available in the contract, River will attempt to pull as muchETH as possible. This maximum is defined by the upper bound allowed by the Oracle. This means that it might take multiplereports for funds to be pulled entirely into the system due to this upper bound, ensuring a lower secondary market impact.The value provided to this contract is computed off-chain and provided manually by Alluvial or any authorized insurance entity.The Coverage funds are pulled upon an oracle report, after the ELFees have been pulled in the system, if there is a margin leftbefore crossing the upper bound. The reason behind this is to favor the revenue stream, that depends on market and network usage, whilethe coverage fund will be pulled after the revenue stream, and there won&#39;t be any commission on the eth pulled.Once a Slashing event occurs, the team will do its best to inject the recovery funds in at maximum 365 daysThe entities allowed to donate are selected by the team. It will mainly be treasury entities or insurance protocols able to fill this coverage fund properly.



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
| donator `indexed` | address | undefined |
| amount  | uint256 | undefined |

### Initialize

```solidity
event Initialize(uint256 version, bytes cdata)
```

Emitted when the contract is properly initialized



#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint256 | undefined |
| cdata  | bytes | undefined |

### SetRiver

```solidity
event SetRiver(address indexed river)
```

The storage river address has changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| river `indexed` | address | undefined |



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


