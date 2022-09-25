# IOperatorsRegistryV1









## Methods

### addOperator

```solidity
function addOperator(string _name, address _operator) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _name | string | undefined |
| _operator | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### addValidators

```solidity
function addValidators(uint256 _index, uint256 _keyCount, bytes _publicKeysAndSignatures) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | undefined |
| _keyCount | uint256 | undefined |
| _publicKeysAndSignatures | bytes | undefined |

### getOperator

```solidity
function getOperator(uint256 _index) external view returns (struct Operators.Operator)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | Operators.Operator | undefined |

### getOperatorCount

```solidity
function getOperatorCount() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getRiver

```solidity
function getRiver() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getValidator

```solidity
function getValidator(uint256 _operatorIndex, uint256 _validatorIndex) external view returns (bytes publicKey, bytes signature, bool funded)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _operatorIndex | uint256 | undefined |
| _validatorIndex | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| publicKey | bytes | undefined |
| signature | bytes | undefined |
| funded | bool | undefined |

### initOperatorsRegistryV1

```solidity
function initOperatorsRegistryV1(address _admin, address _river) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _admin | address | undefined |
| _river | address | undefined |

### listActiveOperators

```solidity
function listActiveOperators() external view returns (struct Operators.Operator[])
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | Operators.Operator[] | undefined |

### pickNextValidators

```solidity
function pickNextValidators(uint256 _count) external nonpayable returns (bytes[] publicKeys, bytes[] signatures)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _count | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| publicKeys | bytes[] | undefined |
| signatures | bytes[] | undefined |

### removeValidators

```solidity
function removeValidators(uint256 _index, uint256[] _indexes) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | undefined |
| _indexes | uint256[] | undefined |

### setOperatorAddress

```solidity
function setOperatorAddress(uint256 _index, address _newOperatorAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | undefined |
| _newOperatorAddress | address | undefined |

### setOperatorLimits

```solidity
function setOperatorLimits(uint256[] _operatorIndexes, uint256[] _newLimits) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _operatorIndexes | uint256[] | undefined |
| _newLimits | uint256[] | undefined |

### setOperatorName

```solidity
function setOperatorName(uint256 _index, string _newName) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | undefined |
| _newName | string | undefined |

### setOperatorStatus

```solidity
function setOperatorStatus(uint256 _index, bool _newStatus) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | undefined |
| _newStatus | bool | undefined |

### setOperatorStoppedValidatorCount

```solidity
function setOperatorStoppedValidatorCount(uint256 _index, uint256 _newStoppedValidatorCount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | undefined |
| _newStoppedValidatorCount | uint256 | undefined |

### setRiver

```solidity
function setRiver(address _newRiver) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newRiver | address | undefined |



## Events

### AddedOperator

```solidity
event AddedOperator(uint256 indexed index, string name, address indexed operatorAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| name  | string | undefined |
| operatorAddress `indexed` | address | undefined |

### AddedValidatorKeys

```solidity
event AddedValidatorKeys(uint256 indexed index, bytes publicKeysAndSignatures)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| publicKeysAndSignatures  | bytes | undefined |

### RemovedValidatorKey

```solidity
event RemovedValidatorKey(uint256 indexed index, bytes publicKey)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| publicKey  | bytes | undefined |

### SetOperatorAddress

```solidity
event SetOperatorAddress(uint256 indexed index, address indexed newOperatorAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newOperatorAddress `indexed` | address | undefined |

### SetOperatorLimit

```solidity
event SetOperatorLimit(uint256 indexed index, uint256 newLimit)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newLimit  | uint256 | undefined |

### SetOperatorName

```solidity
event SetOperatorName(uint256 indexed name, string newName)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| name `indexed` | uint256 | undefined |
| newName  | string | undefined |

### SetOperatorStatus

```solidity
event SetOperatorStatus(uint256 indexed index, bool active)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| active  | bool | undefined |

### SetOperatorStoppedValidatorCount

```solidity
event SetOperatorStoppedValidatorCount(uint256 indexed index, uint256 newStoppedValidatorCount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newStoppedValidatorCount  | uint256 | undefined |

### SetRiver

```solidity
event SetRiver(address indexed river)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| river `indexed` | address | undefined |



## Errors

### InactiveOperator

```solidity
error InactiveOperator(uint256 index)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | undefined |

### InvalidArrayLengths

```solidity
error InvalidArrayLengths()
```






### InvalidEmptyArray

```solidity
error InvalidEmptyArray()
```






### InvalidFundedKeyDeletionAttempt

```solidity
error InvalidFundedKeyDeletionAttempt()
```






### InvalidIndexOutOfBounds

```solidity
error InvalidIndexOutOfBounds()
```






### InvalidKeyCount

```solidity
error InvalidKeyCount()
```






### InvalidKeysLength

```solidity
error InvalidKeysLength()
```






### InvalidPublicKeysLength

```solidity
error InvalidPublicKeysLength()
```






### InvalidSignatureLength

```solidity
error InvalidSignatureLength()
```






### InvalidUnsortedIndexes

```solidity
error InvalidUnsortedIndexes()
```






### OperatorAlreadyExists

```solidity
error OperatorAlreadyExists(string name)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| name | string | undefined |

### OperatorLimitTooHigh

```solidity
error OperatorLimitTooHigh(uint256 limit, uint256 keyCount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| limit | uint256 | undefined |
| keyCount | uint256 | undefined |

### OperatorLimitTooLow

```solidity
error OperatorLimitTooLow(uint256 limit, uint256 fundedKeyCount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| limit | uint256 | undefined |
| fundedKeyCount | uint256 | undefined |


