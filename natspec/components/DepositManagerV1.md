# DepositManagerV1

*Kiln*

> Deposit Manager (v1)

This contract handles the interactions with the official deposit contract, funding all validators

*_onValidatorKeyRequest must be overriden.*

## Methods

### DEPOSIT_SIZE

```solidity
function DEPOSIT_SIZE() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### PUBLIC_KEY_LENGTH

```solidity
function PUBLIC_KEY_LENGTH() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### SIGNATURE_LENGTH

```solidity
function SIGNATURE_LENGTH() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### depositToConsensusLayer

```solidity
function depositToConsensusLayer(uint256 _maxCount) external nonpayable
```

Deposits current balance to the Consensus Layer by batches of 32 ETH



#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxCount | uint256 | The maximum amount of validator keys to fund |

### getDepositedValidatorCount

```solidity
function getDepositedValidatorCount() external view returns (uint256 depositedValidatorCount)
```

Get the deposited validator count (the count of deposits made by the contract)




#### Returns

| Name | Type | Description |
|---|---|---|
| depositedValidatorCount | uint256 | undefined |

### getWithdrawalCredentials

```solidity
function getWithdrawalCredentials() external view returns (bytes32)
```

Retrieve the withdrawal credentials




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |



## Events

### FundedValidatorKey

```solidity
event FundedValidatorKey(bytes publicKey)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| publicKey  | bytes | undefined |



## Errors

### InconsistentPublicKeys

```solidity
error InconsistentPublicKeys()
```






### InconsistentSignatures

```solidity
error InconsistentSignatures()
```






### InvalidPublicKeyCount

```solidity
error InvalidPublicKeyCount()
```






### InvalidSignatureCount

```solidity
error InvalidSignatureCount()
```






### InvalidWithdrawalCredentials

```solidity
error InvalidWithdrawalCredentials()
```






### NoAvailableValidatorKeys

```solidity
error NoAvailableValidatorKeys()
```






### NotEnoughFunds

```solidity
error NotEnoughFunds()
```







