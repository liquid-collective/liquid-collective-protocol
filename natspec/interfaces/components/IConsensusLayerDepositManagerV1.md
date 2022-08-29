# IConsensusLayerDepositManagerV1









## Methods

### depositToConsensusLayer

```solidity
function depositToConsensusLayer(uint256 _maxCount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxCount | uint256 | undefined |

### getDepositedValidatorCount

```solidity
function getDepositedValidatorCount() external view returns (uint256 depositedValidatorCount)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| depositedValidatorCount | uint256 | undefined |

### getWithdrawalCredentials

```solidity
function getWithdrawalCredentials() external view returns (bytes32)
```






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







