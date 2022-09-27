# IConsensusLayerDepositManagerV1









## Methods

### depositToConsensusLayer

```solidity
function depositToConsensusLayer(uint256 _maxCount) external nonpayable
```

Deposits current balance to the Consensus Layer by batches of 32 ETH



#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxCount | uint256 | The maximum amount of validator keys to fund |

### getBalanceToDeposit

```solidity
function getBalanceToDeposit() external view returns (uint256)
```

Returns the amount of pending ETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of pending eth |

### getDepositedValidatorCount

```solidity
function getDepositedValidatorCount() external view returns (uint256)
```

Get the deposited validator count (the count of deposits made by the contract)




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The deposited validator count |

### getWithdrawalCredentials

```solidity
function getWithdrawalCredentials() external view returns (bytes32)
```

Retrieve the withdrawal credentials




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | The withdrawal credentials |



## Events

### FundedValidatorKey

```solidity
event FundedValidatorKey(bytes publicKey)
```

A validator key got funded on the deposit contract



#### Parameters

| Name | Type | Description |
|---|---|---|
| publicKey  | bytes | BLS Public key that got funded |

### SetDepositContractAddress

```solidity
event SetDepositContractAddress(address indexed depositContract)
```

The stored deposit contract address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| depositContract `indexed` | address | Address of the deposit contract |

### SetWithdrawalCredentials

```solidity
event SetWithdrawalCredentials(bytes32 withdrawalCredentials)
```

The stored withdrawals credentials changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| withdrawalCredentials  | bytes32 | The withdrawal credentials to use for deposits |



## Errors

### ErrorOnDeposit

```solidity
error ErrorOnDeposit()
```

An error occured during the deposit




### InconsistentPublicKeys

```solidity
error InconsistentPublicKeys()
```

The length of the BLS Public key is invalid during deposit




### InconsistentSignatures

```solidity
error InconsistentSignatures()
```

The length of the BLS Signature is invalid during deposit




### InvalidPublicKeyCount

```solidity
error InvalidPublicKeyCount()
```

The received count of public keys to deposit is invalid




### InvalidSignatureCount

```solidity
error InvalidSignatureCount()
```

The received count of signatures to deposit is invalid




### InvalidWithdrawalCredentials

```solidity
error InvalidWithdrawalCredentials()
```

The withdrawal credentials value is null




### NoAvailableValidatorKeys

```solidity
error NoAvailableValidatorKeys()
```

The internal key retrieval returned no keys




### NotEnoughFunds

```solidity
error NotEnoughFunds()
```

Not enough funds to deposit one validator





