# OperatorsRegistryV1

*Kiln*

> OperatorsRegistry (v1)

This contract handles the list of operators and their keys



## Methods

### acceptOwnership

```solidity
function acceptOwnership() external nonpayable
```

Accepts the ownership of the system




### addOperator

```solidity
function addOperator(string _name, address _operator, address _feeRecipient) external nonpayable
```

Adds an operator to the registry

*Only callable by the administrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _name | string | The name identifying the operator |
| _operator | address | The address representing the operator, receiving the rewards |
| _feeRecipient | address | The address where the rewards are sent |

### addValidators

```solidity
function addValidators(uint256 _index, uint256 _keyCount, bytes _publicKeys, bytes _signatures) external nonpayable
```

Adds new keys for an operator

*Only callable by the administrator or the operator address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _keyCount | uint256 | The amount of keys provided |
| _publicKeys | bytes | Public keys of the validator, concatenated |
| _signatures | bytes | Signatures of the validator keys, concatenated |

### getAdministrator

```solidity
function getAdministrator() external view returns (address)
```

Retrieve system administrator address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getOperator

```solidity
function getOperator(uint256 _index) external view returns (struct Operators.Operator)
```

Get operator details



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The index of the operator |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | Operators.Operator | undefined |

### getOperatorCount

```solidity
function getOperatorCount() external view returns (uint256)
```

Get operator count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getOperatorDetails

```solidity
function getOperatorDetails(string _name) external view returns (int256 _index, address _operatorAddress)
```

Retrieve the operator details from the operator name



#### Parameters

| Name | Type | Description |
|---|---|---|
| _name | string | Name of the operator |

#### Returns

| Name | Type | Description |
|---|---|---|
| _index | int256 | undefined |
| _operatorAddress | address | undefined |

### getPendingAdministrator

```solidity
function getPendingAdministrator() external view returns (address)
```

Retrieve system pending administrator address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getRiver

```solidity
function getRiver() external view returns (address)
```

Retrieve the River address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getValidator

```solidity
function getValidator(uint256 _operatorIndex, uint256 _validatorIndex) external view returns (bytes publicKey, bytes signature, bool funded)
```

Get the details of a validator



#### Parameters

| Name | Type | Description |
|---|---|---|
| _operatorIndex | uint256 | The index of the operator |
| _validatorIndex | uint256 | The index of the validator |

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

Initializes the operators registry



#### Parameters

| Name | Type | Description |
|---|---|---|
| _admin | address | Admin in charge of managing operators |
| _river | address | Address of River system |

### listActiveOperators

```solidity
function listActiveOperators() external view returns (struct Operators.Operator[])
```

Retrieve the active operator set




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | Operators.Operator[] | undefined |

### pickNextValidators

```solidity
function pickNextValidators(uint256 _requestedAmount) external nonpayable returns (bytes[] publicKeys, bytes[] signatures)
```

Retrieve validator keys based on operator statuses



#### Parameters

| Name | Type | Description |
|---|---|---|
| _requestedAmount | uint256 | Max amount of keys requested |

#### Returns

| Name | Type | Description |
|---|---|---|
| publicKeys | bytes[] | undefined |
| signatures | bytes[] | undefined |

### removeValidators

```solidity
function removeValidators(uint256 _index, uint256[] _indexes) external nonpayable
```

Remove validator keys

*Only callable by the administrator or the operator addressThe indexes must be provided sorted in decreasing order, otherwise the method will revertThe operator limit will be set to the lowest deleted key index*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _indexes | uint256[] | The indexes of the keys to remove |

### setOperatorAddress

```solidity
function setOperatorAddress(uint256 _index, address _newOperatorAddress) external nonpayable
```

Changes the operator address of an operator

*Only callable by the administrator or the previous operator address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _newOperatorAddress | address | The new address of the operator |

### setOperatorFeeRecipientAddress

```solidity
function setOperatorFeeRecipientAddress(uint256 _index, address _newOperatorFeeRecipientAddress) external nonpayable
```

Changes the operator fee recipient address

*Only callable by the administrator or the previous operator fee recipient address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _newOperatorFeeRecipientAddress | address | The new fee recipient address of the operator |

### setOperatorLimits

```solidity
function setOperatorLimits(uint256[] _operatorIndexes, uint256[] _newLimits) external nonpayable
```

Changes the operator staking limit

*Only callable by the administratorThe limit cannot exceed the total key count of the operatorThe _indexes and _newLimits must have the same length.Each limit value is applied to the operator index at the same index in the _indexes array.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _operatorIndexes | uint256[] | The operator indexes |
| _newLimits | uint256[] | The new staking limit of the operators |

### setOperatorName

```solidity
function setOperatorName(uint256 _index, string _newName) external nonpayable
```

Changes the operator name

*Only callable by the administrator or the operatorNo name conflict can exist*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _newName | string | The new operator name |

### setOperatorStatus

```solidity
function setOperatorStatus(uint256 _index, bool _newStatus) external nonpayable
```

Changes the operator status

*Only callable by the administrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _newStatus | bool | The new status of the operator |

### setOperatorStoppedValidatorCount

```solidity
function setOperatorStoppedValidatorCount(uint256 _index, uint256 _newStoppedValidatorCount) external nonpayable
```

Changes the operator stopped validator cound

*Only callable by the administrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _newStoppedValidatorCount | uint256 | The new stopped validator count of the operator |

### setRiver

```solidity
function setRiver(address _newRiver) external nonpayable
```

Change the River address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newRiver | address | New address for the river system |

### transferOwnership

```solidity
function transferOwnership(address _newAdmin) external nonpayable
```

Changes the admin but waits for new admin approval



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | New address for the admin |



## Events

### AddedOperator

```solidity
event AddedOperator(uint256 indexed index, string name, address operatorAddress, address feeRecipientAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| name  | string | undefined |
| operatorAddress  | address | undefined |
| feeRecipientAddress  | address | undefined |

### AddedValidatorKeys

```solidity
event AddedValidatorKeys(uint256 indexed index, bytes publicKeys)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| publicKeys  | bytes | undefined |

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
event SetOperatorAddress(uint256 indexed index, address newOperatorAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newOperatorAddress  | address | undefined |

### SetOperatorFeeRecipientAddress

```solidity
event SetOperatorFeeRecipientAddress(uint256 indexed index, address newOperatorAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newOperatorAddress  | address | undefined |

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



## Errors

### InactiveOperator

```solidity
error InactiveOperator(uint256 index)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | undefined |

### InvalidArgument

```solidity
error InvalidArgument()
```






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






### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | undefined |
| expectedVersion | uint256 | undefined |

### InvalidKeyCount

```solidity
error InvalidKeyCount()
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






### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
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

### OperatorNotFound

```solidity
error OperatorNotFound(string name)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| name | string | undefined |

### OperatorNotFoundAtIndex

```solidity
error OperatorNotFoundAtIndex(uint256 index)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | undefined |

### Unauthorized

```solidity
error Unauthorized(address caller)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | undefined |


