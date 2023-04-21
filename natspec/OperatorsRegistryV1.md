# OperatorsRegistryV1

*Kiln*

> Operators Registry (v1)

This contract handles the list of operators and their keys



## Methods

### acceptAdmin

```solidity
function acceptAdmin() external nonpayable
```

Accept the transfer of ownership

*Only callable by the pending admin. Resets the pending admin if succesful.*


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
function addValidators(uint256 _index, uint32 _keyCount, bytes _publicKeysAndSignatures) external nonpayable
```

Adds new keys for an operator

*Only callable by the administrator or the operator address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _keyCount | uint32 | The amount of keys provided |
| _publicKeysAndSignatures | bytes | Public keys of the validator, concatenated |

### demandValidatorExits

```solidity
function demandValidatorExits(uint256 _count, uint256 _depositedValidatorCount) external nonpayable
```

Increases the exit request demand

*This method is only callable by the river contract, and to actually forward the information to the node operators via event emission, the unprotected requestValidatorExits method must be called*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _count | uint256 | The amount of exit requests to add to the demand |
| _depositedValidatorCount | uint256 | The total deposited validator count |

### forceFundedValidatorKeysEventEmission

```solidity
function forceFundedValidatorKeysEventEmission(uint256 _amountToEmit) external nonpayable
```

Utility to force the broadcasting of events. Will keep its progress in storage to prevent being DoSed by the number of keys



#### Parameters

| Name | Type | Description |
|---|---|---|
| _amountToEmit | uint256 | The amount of events to emit at maximum in this call |

### getAdmin

```solidity
function getAdmin() external view returns (address)
```

Retrieves the current admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The admin address |

### getCurrentValidatorExitsDemand

```solidity
function getCurrentValidatorExitsDemand() external view returns (uint256)
```

Get the current exit request demand waiting to be triggeredThis value is the amount of exit requests that are demanded and not yet performed by the contract




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current exit request demand |

### getOperator

```solidity
function getOperator(uint256 _index) external view returns (struct OperatorsV2.Operator)
```

Get operator details



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The index of the operator |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | OperatorsV2.Operator | The details of the operator |

### getOperatorCount

```solidity
function getOperatorCount() external view returns (uint256)
```

Get operator count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The operator count |

### getOperatorStoppedValidatorCount

```solidity
function getOperatorStoppedValidatorCount(uint256 _idx) external view returns (uint32)
```

Retrieve the stopped validator count for an operator index



#### Parameters

| Name | Type | Description |
|---|---|---|
| _idx | uint256 | The index of the operator |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | The stopped validator count of the operator |

### getPendingAdmin

```solidity
function getPendingAdmin() external view returns (address)
```

Retrieve the current pending admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The pending admin address |

### getRiver

```solidity
function getRiver() external view returns (address)
```

Retrieve the River address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The address of River |

### getStoppedAndRequestedExitCounts

```solidity
function getStoppedAndRequestedExitCounts() external view returns (uint32, uint256)
```

Retrieve the total stopped and requested exit count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | The total stopped count |
| _1 | uint256 | The total requested exit count |

### getStoppedValidatorCountPerOperator

```solidity
function getStoppedValidatorCountPerOperator() external view returns (uint32[])
```

Retrieve the raw stopped validators array from storage




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32[] | The stopped validator array |

### getTotalStoppedValidatorCount

```solidity
function getTotalStoppedValidatorCount() external view returns (uint32)
```

Retrieve the total stopped validator count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | The total stopped validator count |

### getTotalValidatorExitsRequested

```solidity
function getTotalValidatorExitsRequested() external view returns (uint256)
```

Retrieve the total requested exit countThis value is the amount of exit requests that have been performed, emitting an event for operators to catch




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The total requested exit count |

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

### initOperatorsRegistryV1_1

```solidity
function initOperatorsRegistryV1_1() external nonpayable
```

Initializes the operators registry for V1_1




### listActiveOperators

```solidity
function listActiveOperators() external view returns (struct OperatorsV2.Operator[])
```

Retrieve the active operator set




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | OperatorsV2.Operator[] | The list of active operators and their details |

### pickNextValidatorsToDeposit

```solidity
function pickNextValidatorsToDeposit(uint256 _count) external nonpayable returns (bytes[] publicKeys, bytes[] signatures)
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

### proposeAdmin

```solidity
function proposeAdmin(address _newAdmin) external nonpayable
```

Proposes a new address as admin

*This security prevents setting an invalid address as an admin. The pendingadmin has to claim its ownership of the contract, and prove that the newaddress is able to perform regular transactions.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | New admin address |

### removeValidators

```solidity
function removeValidators(uint256 _index, uint256[] _indexes) external nonpayable
```

Remove validator keys

*Only callable by the administrator or the operator addressThe indexes must be provided sorted in decreasing order and duplicate-free, otherwise the method will revertThe operator limit will be set to the lowest deleted key index if the operator&#39;s limit wasn&#39;t equal to its total key countThe operator or the admin cannot remove funded keysWhen removing validators, the indexes of specific unfunded keys can be changed in order to properlyremove the keys from the storage array. Beware of this specific behavior when chaining calls as thetargeted public key indexes can point to a different key after a first call was made and performedsome swaps*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _indexes | uint256[] | The indexes of the keys to remove |

### reportStoppedValidatorCounts

```solidity
function reportStoppedValidatorCounts(uint32[] _stoppedValidatorCounts, uint256 _depositedValidatorCount) external nonpayable
```

Allows river to override the stopped validators arrayThis actions happens during the Oracle report processing



#### Parameters

| Name | Type | Description |
|---|---|---|
| _stoppedValidatorCounts | uint32[] | The new stopped validators array |
| _depositedValidatorCount | uint256 | The total deposited validator count |

### requestValidatorExits

```solidity
function requestValidatorExits(uint256 _count) external nonpayable
```

Public endpoint to consume the exit request demand and perform the actual exit requestsThe selection algorithm will pick validators based on their active validator countsThis value is computed by using the count of funded keys and taking into account the stopped validator counts and exit requests



#### Parameters

| Name | Type | Description |
|---|---|---|
| _count | uint256 | Max amount of exits to request |

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
function setOperatorLimits(uint256[] _operatorIndexes, uint32[] _newLimits, uint256 _snapshotBlock) external nonpayable
```

Changes the operator staking limit

*Only callable by the administratorThe operator indexes must be in increasing order and contain no duplicateThe limit cannot exceed the total key count of the operatorThe _indexes and _newLimits must have the same length.Each limit value is applied to the operator index at the same index in the _indexes array.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _operatorIndexes | uint256[] | The operator indexes, in increasing order and duplicate free |
| _newLimits | uint32[] | The new staking limit of the operators |
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



## Events

### AddedOperator

```solidity
event AddedOperator(uint256 indexed index, string name, address indexed operatorAddress)
```

A new operator has been added to the registry



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

The operator or the admin added new validator keys and signatures



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| publicKeysAndSignatures  | bytes | undefined |

### FundedValidatorKeys

```solidity
event FundedValidatorKeys(uint256 indexed index, bytes[] publicKeys, bool deferred)
```

A validator key got funded on the deposit contractThis event was introduced during a contract upgrade, in order to cover all possible public keys, this eventwill be replayed for past funded keys in order to have a complete coverage of all the funded public keys.In this particuliar scenario, the deferred value will be set to true, to indicate that we are not going to havethe expected additional events and side effects in the same transaction (deposit to official DepositContract etc ...) becausethe event was synthetically crafted.



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| publicKeys  | bytes[] | undefined |
| deferred  | bool | undefined |

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

### OperatorEditsAfterSnapshot

```solidity
event OperatorEditsAfterSnapshot(uint256 indexed index, uint256 currentLimit, uint256 newLimit, uint256 indexed latestKeysEditBlockNumber, uint256 indexed snapshotBlock)
```

The operator edited its keys after the snapshot block



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| currentLimit  | uint256 | undefined |
| newLimit  | uint256 | undefined |
| latestKeysEditBlockNumber `indexed` | uint256 | undefined |
| snapshotBlock `indexed` | uint256 | undefined |

### OperatorLimitUnchanged

```solidity
event OperatorLimitUnchanged(uint256 indexed index, uint256 limit)
```

The call didn&#39;t alter the limit of the operator



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| limit  | uint256 | undefined |

### RemovedValidatorKey

```solidity
event RemovedValidatorKey(uint256 indexed index, bytes publicKey)
```

The operator or the admin removed a public key and its signature from the registry



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| publicKey  | bytes | undefined |

### RequestedValidatorExits

```solidity
event RequestedValidatorExits(uint256 indexed index, uint256 count)
```

The requested exit count has been updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| count  | uint256 | undefined |

### SetAdmin

```solidity
event SetAdmin(address indexed admin)
```

The admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| admin `indexed` | address | undefined |

### SetCurrentValidatorExitsDemand

```solidity
event SetCurrentValidatorExitsDemand(uint256 previousValidatorExitsDemand, uint256 nextValidatorExitsDemand)
```

The exit request demand has been updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| previousValidatorExitsDemand  | uint256 | undefined |
| nextValidatorExitsDemand  | uint256 | undefined |

### SetOperatorAddress

```solidity
event SetOperatorAddress(uint256 indexed index, address indexed newOperatorAddress)
```

The operator address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newOperatorAddress `indexed` | address | undefined |

### SetOperatorLimit

```solidity
event SetOperatorLimit(uint256 indexed index, uint256 newLimit)
```

The operator limit has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newLimit  | uint256 | undefined |

### SetOperatorName

```solidity
event SetOperatorName(uint256 indexed index, string newName)
```

The operator display name has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newName  | string | undefined |

### SetOperatorStatus

```solidity
event SetOperatorStatus(uint256 indexed index, bool active)
```

The operator status has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| active  | bool | undefined |

### SetOperatorStoppedValidatorCount

```solidity
event SetOperatorStoppedValidatorCount(uint256 indexed index, uint256 newStoppedValidatorCount)
```

The operator stopped validator count has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newStoppedValidatorCount  | uint256 | undefined |

### SetPendingAdmin

```solidity
event SetPendingAdmin(address indexed pendingAdmin)
```

The pending admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| pendingAdmin `indexed` | address | undefined |

### SetRiver

```solidity
event SetRiver(address indexed river)
```

The stored river address has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| river `indexed` | address | undefined |

### SetTotalValidatorExitsRequested

```solidity
event SetTotalValidatorExitsRequested(uint256 previousTotalValidatorExitsRequested, uint256 newTotalValidatorExitsRequested)
```

The total requested exit has been updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| previousTotalValidatorExitsRequested  | uint256 | undefined |
| newTotalValidatorExitsRequested  | uint256 | undefined |

### UpdatedRequestedValidatorExitsUponStopped

```solidity
event UpdatedRequestedValidatorExitsUponStopped(uint256 indexed index, uint32 oldRequestedExits, uint32 newRequestedExits)
```

The requested exit count has been update to fill the gap with the reported stopped count



#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| oldRequestedExits  | uint32 | undefined |
| newRequestedExits  | uint32 | undefined |

### UpdatedStoppedValidators

```solidity
event UpdatedStoppedValidators(uint32[] stoppedValidatorCounts)
```

The stopped validator array has been changedA validator is considered stopped if exiting, exited or slashedThis event is emitted when the oracle reports new stopped validators counts



#### Parameters

| Name | Type | Description |
|---|---|---|
| stoppedValidatorCounts  | uint32[] | undefined |



## Errors

### FundedKeyEventMigrationComplete

```solidity
error FundedKeyEventMigrationComplete()
```

Emitted when the event rebroadcasting is done and we attempt to broadcast new events




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




### InvalidEmptyStoppedValidatorCountsArray

```solidity
error InvalidEmptyStoppedValidatorCountsArray()
```

Thrown when an invalid empty stopped validator array is provided




### InvalidEmptyString

```solidity
error InvalidEmptyString()
```

The string is empty




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




### InvalidStoppedValidatorCountsSum

```solidity
error InvalidStoppedValidatorCountsSum()
```

Thrown when the sum of stopped validators is invalid




### InvalidUnsortedIndexes

```solidity
error InvalidUnsortedIndexes()
```

The index provided are not sorted properly (descending order)




### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero




### NoExitRequestsToPerform

```solidity
error NoExitRequestsToPerform()
```

Thrown when no exit requests can be performed




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

### OperatorNotFound

```solidity
error OperatorNotFound(uint256 index)
```

The operator was not found



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | The provided index |

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




### StoppedValidatorCountAboveFundedCount

```solidity
error StoppedValidatorCountAboveFundedCount(uint256 operatorIndex, uint32 stoppedCount, uint32 fundedCount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| operatorIndex | uint256 | undefined |
| stoppedCount | uint32 | undefined |
| fundedCount | uint32 | undefined |

### StoppedValidatorCountArrayShrinking

```solidity
error StoppedValidatorCountArrayShrinking()
```






### StoppedValidatorCountsDecreased

```solidity
error StoppedValidatorCountsDecreased()
```

Throw when an element in the stopped validator array is decreasing




### StoppedValidatorCountsTooHigh

```solidity
error StoppedValidatorCountsTooHigh()
```

Thrown when the number of elements in the array is too high compared to operator count




### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Address performing the call |

### UnorderedOperatorList

```solidity
error UnorderedOperatorList()
```

The provided list of operators is not in increasing order





