# IOperatorsRegistryV1

*Kiln*

> Operators Registry Interface (v1)

This interface exposes methods to handle the list of operators and their keys



## Methods

### addOperator

```solidity
function addOperator(string _name, address _operator) external nonpayable returns (uint256)
```

Adds an operator to the registry

*Only callable by the administrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _name | string | The name identifying the operator |
| _operator | address | The address representing the operator, receiving the rewards |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The index of the new operator |

### addValidators

```solidity
function addValidators(uint256 _index, uint256 _keyCount, bytes _publicKeysAndSignatures) external nonpayable
```

Adds new keys for an operator

*Only callable by the administrator or the operator address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _keyCount | uint256 | The amount of keys provided |
| _publicKeysAndSignatures | bytes | Public keys of the validator, concatenated |

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
| _0 | Operators.Operator | The details of the operator |

### getOperatorCount

```solidity
function getOperatorCount() external view returns (uint256)
```

Get operator count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The operator count |

### getRiver

```solidity
function getRiver() external view returns (address)
```

Retrieve the River address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The address of River |

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
| publicKey | bytes | The public key of the validator |
| signature | bytes | The signature used during deposit |
| funded | bool | True if validator has been funded |

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
| _0 | Operators.Operator[] | The list of active operators and their details |

### pickNextValidators

```solidity
function pickNextValidators(uint256 _count) external nonpayable returns (bytes[] publicKeys, bytes[] signatures)
```

Retrieve validator keys based on operator statuses



#### Parameters

| Name | Type | Description |
|---|---|---|
| _count | uint256 | Max amount of keys requested |

#### Returns

| Name | Type | Description |
|---|---|---|
| publicKeys | bytes[] | An array of public keys |
| signatures | bytes[] | An array of signatures linked to the public keys |

### removeValidators

```solidity
function removeValidators(uint256 _index, uint256[] _indexes) external nonpayable
```

Remove validator keys

*Only callable by the administrator or the operator addressThe indexes must be provided sorted in decreasing order and duplicate-free, otherwise the method will revertThe operator limit will be set to the lowest deleted key index if the operator&#39;s limit wasn&#39;t equal to its total key countThe operator or the admin cannot remove funded keys*

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

### setOperatorLimits

```solidity
function setOperatorLimits(uint256[] _operatorIndexes, uint256[] _newLimits, uint256 _snapshotBlock) external nonpayable
```

Changes the operator staking limit

*Only callable by the administratorThe operator indexes must be in increasing order and contain no duplicateThe limit cannot exceed the total key count of the operatorThe _indexes and _newLimits must have the same length.Each limit value is applied to the operator index at the same index in the _indexes array.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _operatorIndexes | uint256[] | The operator indexes, in increasing order and duplicate free |
| _newLimits | uint256[] | The new staking limit of the operators |
| _snapshotBlock | uint256 | The block number at which the snapshot was computed |

### setOperatorName

```solidity
function setOperatorName(uint256 _index, string _newName) external nonpayable
```

Changes the operator name

*Only callable by the administrator or the operator*

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

Changes the operator stopped validator count

*Only callable by the administrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _newStoppedValidatorCount | uint256 | The new stopped validator count of the operator |



## Events

### AddedOperator

```solidity
event AddedOperator(uint256 indexed index, string name, address indexed operatorAddress)
```

A new operator has been added to the registry



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | The operator index |
| name  | string | The operator display name |
| operatorAddress `indexed` | address | The operator address |

### AddedValidatorKeys

```solidity
event AddedValidatorKeys(uint256 indexed index, bytes publicKeysAndSignatures)
```

The operator or the admin added new validator keys and signatures

*The public keys and signatures are concatenatedA public key is 48 bytes longA signature is 96 bytes long[P1, S1, P2, S2, ..., PN, SN] where N is the bytes length divided by (96 + 48)*

#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | The operator index |
| publicKeysAndSignatures  | bytes | The concatenated public keys and signatures |

### OperatorEditsAfterSnapshot

```solidity
event OperatorEditsAfterSnapshot(uint256 indexed index, uint256 currentLimit, uint256 newLimit, uint256 indexed latestKeysEditBlockNumber, uint256 indexed snapshotBlock)
```

The operator edited its keys after the snapshot block

*This means that we cannot assume that its key set is checked by the snapshotThis happens only if the limit was meant to be increased*

#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | The operator index |
| currentLimit  | uint256 | The current operator limit |
| newLimit  | uint256 | The new operator limit that was attempted to be set |
| latestKeysEditBlockNumber `indexed` | uint256 | The last block number at which the operator changed its keys |
| snapshotBlock `indexed` | uint256 | The block number of the snapshot |

### OperatorLimitUnchanged

```solidity
event OperatorLimitUnchanged(uint256 indexed index, uint256 limit)
```

The call didn&#39;t alter the limit of the operator



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | The operator index |
| limit  | uint256 | The limit of the operator |

### RemovedValidatorKey

```solidity
event RemovedValidatorKey(uint256 indexed index, bytes publicKey)
```

The operator or the admin removed a public key and its signature from the registry



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | The operator index |
| publicKey  | bytes | The BLS public key that has been removed |

### SetOperatorAddress

```solidity
event SetOperatorAddress(uint256 indexed index, address indexed newOperatorAddress)
```

The operator address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | The operator index |
| newOperatorAddress `indexed` | address | The new operator address |

### SetOperatorLimit

```solidity
event SetOperatorLimit(uint256 indexed index, uint256 newLimit)
```

The operator limit has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | The operator index |
| newLimit  | uint256 | The new operator staking limit |

### SetOperatorName

```solidity
event SetOperatorName(uint256 indexed index, string newName)
```

The operator display name has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | The operator index |
| newName  | string | The new display name |

### SetOperatorStatus

```solidity
event SetOperatorStatus(uint256 indexed index, bool active)
```

The operator status has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | The operator index |
| active  | bool | True if the operator is active |

### SetOperatorStoppedValidatorCount

```solidity
event SetOperatorStoppedValidatorCount(uint256 indexed index, uint256 newStoppedValidatorCount)
```

The operator stopped validator count has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | The operator index |
| newStoppedValidatorCount  | uint256 | The new stopped validator count |

### SetRiver

```solidity
event SetRiver(address indexed river)
```

The stored river address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| river `indexed` | address | The new river address |



## Errors

### InactiveOperator

```solidity
error InactiveOperator(uint256 index)
```

The calling operator is inactive



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | The operator index |

### InvalidArrayLengths

```solidity
error InvalidArrayLengths()
```

The provided operator and limits array have different lengths




### InvalidEmptyArray

```solidity
error InvalidEmptyArray()
```

The provided operator and limits array are empty




### InvalidFundedKeyDeletionAttempt

```solidity
error InvalidFundedKeyDeletionAttempt()
```

A funded key deletion has been attempted




### InvalidIndexOutOfBounds

```solidity
error InvalidIndexOutOfBounds()
```

The index that is removed is out of bounds




### InvalidKeyCount

```solidity
error InvalidKeyCount()
```

The provided key count is 0




### InvalidKeysLength

```solidity
error InvalidKeysLength()
```

The provided concatenated keys do not have the expected length




### InvalidUnsortedIndexes

```solidity
error InvalidUnsortedIndexes()
```

The index provided are not sorted properly (descending order)




### OperatorLimitTooHigh

```solidity
error OperatorLimitTooHigh(uint256 index, uint256 limit, uint256 keyCount)
```

The value for the operator limit is too high



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | The operator index |
| limit | uint256 | The new limit provided |
| keyCount | uint256 | The operator key count |

### OperatorLimitTooLow

```solidity
error OperatorLimitTooLow(uint256 index, uint256 limit, uint256 fundedKeyCount)
```

The value for the limit is too low



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | The operator index |
| limit | uint256 | The new limit provided |
| fundedKeyCount | uint256 | The operator funded key count |

### UnorderedOperatorList

```solidity
error UnorderedOperatorList()
```

The provided list of operators is not in increasing order





