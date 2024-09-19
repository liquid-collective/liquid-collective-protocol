# WithdrawV1

*Alluvial Finance Inc.*

> Withdraw (v1)

This contract is in charge of holding the exit and skimming funds and allow river to pull these funds



## Methods

### getCredentials

```solidity
function getCredentials() external view returns (bytes32)
```

Retrieve the withdrawal credentials to use




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | The withdrawal credentials |

### getRiver

```solidity
function getRiver() external view returns (address)
```

Retrieve the linked River address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The River address |

### initializeWithdrawV1

```solidity
function initializeWithdrawV1(address _river) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _river | address | The address of the River contract |

### pullEth

```solidity
function pullEth(uint256 _max) external nonpayable
```

Callable by River, sends the specified amount of ETH to River



#### Parameters

| Name | Type | Description |
|---|---|---|
| _max | uint256 | undefined |

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
event SetRiver(address river)
```

Emitted when the linked River address is changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| river  | address | The new River address |



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




### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Address performing the call |


