# ConsensusLayerDepositManagerV1

*Alluvial Finance Inc.*

> Consensus Layer Deposit Manager (v1)

This contract handles the interactions with the official deposit contract, funding all validatorsWhenever a deposit to the consensus layer is requested, this contract computed the amount of keysthat could be deposited depending on the amount available in the contract. It then tries to retrievevalidator keys by calling its internal virtual method _getNextValidators. This method should beoverridden by the implementing contract to provide [0; _keyCount] keys when invoked.



## Methods

### DEPOSIT_SIZE

```solidity
function DEPOSIT_SIZE() external view returns (uint256)
```

Size of a deposit in ETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### PUBLIC_KEY_LENGTH

```solidity
function PUBLIC_KEY_LENGTH() external view returns (uint256)
```

Size of a BLS Public key in bytes




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### SIGNATURE_LENGTH

```solidity
function SIGNATURE_LENGTH() external view returns (uint256)
```

Size of a BLS Signature in bytes




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### depositToConsensusLayerWithDepositRoot

```solidity
function depositToConsensusLayerWithDepositRoot(uint256 _maxCount, bytes32 _depositRoot) external nonpayable
```

Deposits current balance to the Consensus Layer by batches of 32 ETH



#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxCount | uint256 | The maximum amount of validator keys to fund |
| _depositRoot | bytes32 | The root of the deposit tree |

### getBalanceToDeposit

```solidity
function getBalanceToDeposit() external view returns (uint256)
```

Returns the amount of ETH not yet committed for deposit




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of ETH not yet committed for deposit |

### getCommittedBalance

```solidity
function getCommittedBalance() external view returns (uint256)
```

Returns the amount of ETH committed for deposit




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of ETH committed for deposit |

### getDepositedValidatorCount

```solidity
function getDepositedValidatorCount() external view returns (uint256)
```

Get the deposited validator count (the count of deposits made by the contract)




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The deposited validator count |

### getKeeper

```solidity
function getKeeper() external view returns (address)
```

Get the keeper address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The keeper address |

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

### SetDepositContractAddress

```solidity
event SetDepositContractAddress(address indexed depositContract)
```

The stored deposit contract address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| depositContract `indexed` | address | Address of the deposit contract |

### SetDepositedValidatorCount

```solidity
event SetDepositedValidatorCount(uint256 oldDepositedValidatorCount, uint256 newDepositedValidatorCount)
```

Emitted when the deposited validator count is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| oldDepositedValidatorCount  | uint256 | The old deposited validator count value |
| newDepositedValidatorCount  | uint256 | The new deposited validator count value |

### SetWithdrawalCredentials

```solidity
event SetWithdrawalCredentials(bytes32 withdrawalCredentials)
```

The stored withdrawal credentials changed



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




### InvalidDepositRoot

```solidity
error InvalidDepositRoot()
```

Invalid deposit root




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




### OnlyKeeper

```solidity
error OnlyKeeper()
```






### SliceOutOfBounds

```solidity
error SliceOutOfBounds()
```

The slice is outside of the initial bytes bounds




### SliceOverflow

```solidity
error SliceOverflow()
```

The length overflows an uint





