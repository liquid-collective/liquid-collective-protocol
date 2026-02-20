# IOperatorsRegistryV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/IOperatorRegistry.1.sol)

**Title:**
Operators Registry Interface (v1)

**Author:**
Alluvial Finance Inc.

This interface exposes methods to handle the list of operators and their keys


## Functions
### initOperatorsRegistryV1

Initializes the operators registry


```solidity
function initOperatorsRegistryV1(address _admin, address _river) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Admin in charge of managing operators|
|`_river`|`address`|Address of River system|


### initOperatorsRegistryV1_1

Initializes the operators registry for V1_1


```solidity
function initOperatorsRegistryV1_1() external;
```

### getRiver

Retrieve the River address


```solidity
function getRiver() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of River|


### getOperator

Get operator details


```solidity
function getOperator(uint256 _index) external view returns (OperatorsV2.Operator memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The index of the operator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`OperatorsV2.Operator`|The details of the operator|


### getOperatorCount

Get operator count


```solidity
function getOperatorCount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The operator count|


### getOperatorStoppedValidatorCount

Retrieve the stopped validator count for an operator index


```solidity
function getOperatorStoppedValidatorCount(uint256 _idx) external view returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_idx`|`uint256`|The index of the operator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The stopped validator count of the operator|


### getTotalStoppedValidatorCount

Retrieve the total stopped validator count


```solidity
function getTotalStoppedValidatorCount() external view returns (uint32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The total stopped validator count|


### getTotalValidatorExitsRequested

Retrieve the total requested exit count

This value is the amount of exit requests that have been performed, emitting an event for operators to catch


```solidity
function getTotalValidatorExitsRequested() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total requested exit count|


### getCurrentValidatorExitsDemand

Get the current exit request demand waiting to be triggered

This value is the amount of exit requests that are demanded and not yet performed by the contract


```solidity
function getCurrentValidatorExitsDemand() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current exit request demand|


### getStoppedAndRequestedExitCounts

Retrieve the total stopped and requested exit count


```solidity
function getStoppedAndRequestedExitCounts() external view returns (uint32, uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The total stopped count|
|`<none>`|`uint256`|The total requested exit count|


### getStoppedValidatorCountPerOperator

Retrieve the raw stopped validators array from storage


```solidity
function getStoppedValidatorCountPerOperator() external view returns (uint32[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32[]`|The stopped validator array|


### getValidator

Get the details of a validator


```solidity
function getValidator(uint256 _operatorIndex, uint256 _validatorIndex)
    external
    view
    returns (bytes memory publicKey, bytes memory signature, bool funded);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operatorIndex`|`uint256`|The index of the operator|
|`_validatorIndex`|`uint256`|The index of the validator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKey`|`bytes`|The public key of the validator|
|`signature`|`bytes`|The signature used during deposit|
|`funded`|`bool`|True if validator has been funded|


### getNextValidatorsToDepositFromActiveOperators

Get the next validators that would be funded based on the proposed allocations


```solidity
function getNextValidatorsToDepositFromActiveOperators(OperatorAllocation[] memory _allocations)
    external
    view
    returns (bytes[] memory publicKeys, bytes[] memory signatures);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_allocations`|`OperatorAllocation[]`|The proposed allocations to validate|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKeys`|`bytes[]`|An array of fundable public keys|
|`signatures`|`bytes[]`|An array of signatures linked to the public keys|


### listActiveOperators

Retrieve the active operator set


```solidity
function listActiveOperators() external view returns (OperatorsV2.Operator[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`OperatorsV2.Operator[]`|The list of active operators and their details|


### reportStoppedValidatorCounts

Allows river to override the stopped validators array

This actions happens during the Oracle report processing


```solidity
function reportStoppedValidatorCounts(uint32[] calldata _stoppedValidatorCounts, uint256 _depositedValidatorCount)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stoppedValidatorCounts`|`uint32[]`|The new stopped validators array|
|`_depositedValidatorCount`|`uint256`|The total deposited validator count|


### addOperator

Adds an operator to the registry

Only callable by the administrator


```solidity
function addOperator(string calldata _name, address _operator) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_name`|`string`|The name identifying the operator|
|`_operator`|`address`|The address representing the operator, receiving the rewards|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The index of the new operator|


### setOperatorAddress

Changes the operator address of an operator

Only callable by the administrator or the previous operator address


```solidity
function setOperatorAddress(uint256 _index, address _newOperatorAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The operator index|
|`_newOperatorAddress`|`address`|The new address of the operator|


### setOperatorName

Changes the operator name

Only callable by the administrator or the operator


```solidity
function setOperatorName(uint256 _index, string calldata _newName) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The operator index|
|`_newName`|`string`|The new operator name|


### setOperatorStatus

Changes the operator status

Only callable by the administrator


```solidity
function setOperatorStatus(uint256 _index, bool _newStatus) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The operator index|
|`_newStatus`|`bool`|The new status of the operator|


### setOperatorLimits

Changes the operator staking limit

Only callable by the administrator

The operator indexes must be in increasing order and contain no duplicate

The limit cannot exceed the total key count of the operator

The _indexes and _newLimits must have the same length.

Each limit value is applied to the operator index at the same index in the _indexes array.


```solidity
function setOperatorLimits(
    uint256[] calldata _operatorIndexes,
    uint32[] calldata _newLimits,
    uint256 _snapshotBlock
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operatorIndexes`|`uint256[]`|The operator indexes, in increasing order and duplicate free|
|`_newLimits`|`uint32[]`|The new staking limit of the operators|
|`_snapshotBlock`|`uint256`|The block number at which the snapshot was computed|


### addValidators

Adds new keys for an operator

Only callable by the administrator or the operator address


```solidity
function addValidators(uint256 _index, uint32 _keyCount, bytes calldata _publicKeysAndSignatures) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The operator index|
|`_keyCount`|`uint32`|The amount of keys provided|
|`_publicKeysAndSignatures`|`bytes`|Public keys of the validator, concatenated|


### removeValidators

Remove validator keys

Only callable by the administrator or the operator address

The indexes must be provided sorted in decreasing order and duplicate-free, otherwise the method will revert

The operator limit will be set to the lowest deleted key index if the operator's limit wasn't equal to its total key count

The operator or the admin cannot remove funded keys

When removing validators, the indexes of specific unfunded keys can be changed in order to properly

remove the keys from the storage array. Beware of this specific behavior when chaining calls as the

targeted public key indexes can point to a different key after a first call was made and performed

some swaps


```solidity
function removeValidators(uint256 _index, uint256[] calldata _indexes) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The operator index|
|`_indexes`|`uint256[]`|The indexes of the keys to remove|


### pickNextValidatorsToDeposit

Retrieve validator keys based on explicit operator allocations and mark them as funded

Only callable by the river contract

The allocations must be sorted by operator index in strictly ascending order with no duplicates

Each allocation's validatorCount must be non-zero and not exceed the operator's available fundable keys

Reverts with InvalidEmptyArray if _allocations is empty

Reverts with UnorderedOperatorList if operator indexes are not strictly ascending

Reverts with AllocationWithZeroValidatorCount if any allocation has a zero validator count

Reverts with InactiveOperator if a referenced operator is inactive

Reverts with OperatorIgnoredExitRequests if an operator has not complied with exit requests

Reverts with OperatorHasInsufficientFundableKeys if an operator lacks enough fundable keys


```solidity
function pickNextValidatorsToDeposit(OperatorAllocation[] calldata _allocations)
    external
    returns (bytes[] memory publicKeys, bytes[] memory signatures);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_allocations`|`OperatorAllocation[]`|Node operator allocations specifying how many validators per operator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKeys`|`bytes[]`|An array of public keys|
|`signatures`|`bytes[]`|An array of signatures linked to the public keys|


### requestValidatorExits

Process explicit per-operator exit allocations and update operator requestedExits

Only callable by the keeper address returned by the River contract's getKeeper()

The allocations must be sorted by operator index in strictly ascending order with no duplicates

Each allocation's validatorCount must be non-zero and not exceed the operator's available funded-but-not-yet-exited validators

The total requested exits across all allocations must not exceed the current validator exit demand

Reverts with InvalidEmptyArray if _allocations is empty

Reverts with AllocationWithZeroValidatorCount if any allocation has a zero validator count

Reverts with UnorderedOperatorList if operator indexes are not strictly ascending

Reverts with InactiveOperator if a referenced operator is inactive

Reverts with ExitsRequestedExceedAvailableFundedCount if count exceeds funded minus requestedExits for an operator

Reverts with ExitsRequestedExceedDemand if total exits requested exceed the current demand

Reverts with NoExitRequestsToPerform if there is no pending exit demand


```solidity
function requestValidatorExits(OperatorAllocation[] calldata _allocations) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_allocations`|`OperatorAllocation[]`|The proposed per-operator exit allocations, sorted by operator index|


### demandValidatorExits

Increases the exit request demand

This method is only callable by the river contract, and to actually forward the information to the node operators via event emission, the unprotected requestValidatorExits method must be called


```solidity
function demandValidatorExits(uint256 _count, uint256 _depositedValidatorCount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_count`|`uint256`|The amount of exit requests to add to the demand|
|`_depositedValidatorCount`|`uint256`|The total deposited validator count|


## Events
### AddedOperator
A new operator has been added to the registry


```solidity
event AddedOperator(uint256 indexed index, string name, address indexed operatorAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`name`|`string`|The operator display name|
|`operatorAddress`|`address`|The operator address|

### SetOperatorStatus
The operator status has been changed


```solidity
event SetOperatorStatus(uint256 indexed index, bool active);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`active`|`bool`|True if the operator is active|

### SetOperatorLimit
The operator limit has been changed


```solidity
event SetOperatorLimit(uint256 indexed index, uint256 newLimit);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`newLimit`|`uint256`|The new operator staking limit|

### SetOperatorStoppedValidatorCount
The operator stopped validator count has been changed


```solidity
event SetOperatorStoppedValidatorCount(uint256 indexed index, uint256 newStoppedValidatorCount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`newStoppedValidatorCount`|`uint256`|The new stopped validator count|

### SetOperatorAddress
The operator address has been changed


```solidity
event SetOperatorAddress(uint256 indexed index, address indexed newOperatorAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`newOperatorAddress`|`address`|The new operator address|

### SetOperatorName
The operator display name has been changed


```solidity
event SetOperatorName(uint256 indexed index, string newName);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`newName`|`string`|The new display name|

### AddedValidatorKeys
The operator or the admin added new validator keys and signatures

The public keys and signatures are concatenated

A public key is 48 bytes long

A signature is 96 bytes long

[P1, S1, P2, S2, ..., PN, SN] where N is the bytes length divided by (96 + 48)


```solidity
event AddedValidatorKeys(uint256 indexed index, bytes publicKeysAndSignatures);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`publicKeysAndSignatures`|`bytes`|The concatenated public keys and signatures|

### RemovedValidatorKey
The operator or the admin removed a public key and its signature from the registry


```solidity
event RemovedValidatorKey(uint256 indexed index, bytes publicKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`publicKey`|`bytes`|The BLS public key that has been removed|

### SetRiver
The stored river address has been changed


```solidity
event SetRiver(address indexed river);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`river`|`address`|The new river address|

### OperatorEditsAfterSnapshot
The operator edited its keys after the snapshot block

This means that we cannot assume that its key set is checked by the snapshot

This happens only if the limit was meant to be increased


```solidity
event OperatorEditsAfterSnapshot(
    uint256 indexed index,
    uint256 currentLimit,
    uint256 newLimit,
    uint256 indexed latestKeysEditBlockNumber,
    uint256 indexed snapshotBlock
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`currentLimit`|`uint256`|The current operator limit|
|`newLimit`|`uint256`|The new operator limit that was attempted to be set|
|`latestKeysEditBlockNumber`|`uint256`|The last block number at which the operator changed its keys|
|`snapshotBlock`|`uint256`|The block number of the snapshot|

### OperatorLimitUnchanged
The call didn't alter the limit of the operator


```solidity
event OperatorLimitUnchanged(uint256 indexed index, uint256 limit);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`limit`|`uint256`|The limit of the operator|

### UpdatedStoppedValidators
The stopped validator array has been changed

A validator is considered stopped if exiting, exited or slashed

This event is emitted when the oracle reports new stopped validators counts


```solidity
event UpdatedStoppedValidators(uint32[] stoppedValidatorCounts);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stoppedValidatorCounts`|`uint32[]`|The new stopped validator counts|

### RequestedValidatorExits
The requested exit count has been updated


```solidity
event RequestedValidatorExits(uint256 indexed index, uint256 count);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`count`|`uint256`|The count of requested exits|

### SetCurrentValidatorExitsDemand
The exit request demand has been updated


```solidity
event SetCurrentValidatorExitsDemand(uint256 previousValidatorExitsDemand, uint256 nextValidatorExitsDemand);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`previousValidatorExitsDemand`|`uint256`|The previous exit request demand|
|`nextValidatorExitsDemand`|`uint256`|The new exit request demand|

### SetTotalValidatorExitsRequested
The total requested exit has been updated


```solidity
event SetTotalValidatorExitsRequested(
    uint256 previousTotalValidatorExitsRequested, uint256 newTotalValidatorExitsRequested
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`previousTotalValidatorExitsRequested`|`uint256`|The previous total requested exit|
|`newTotalValidatorExitsRequested`|`uint256`|The new total requested exit|

### FundedValidatorKeys
A validator key got funded on the deposit contract

This event was introduced during a contract upgrade, in order to cover all possible public keys, this event

will be replayed for past funded keys in order to have a complete coverage of all the funded public keys.

In this particular scenario, the deferred value will be set to true, to indicate that we are not going to have

the expected additional events and side effects in the same transaction (deposit to official DepositContract etc ...) because

the event was synthetically crafted.


```solidity
event FundedValidatorKeys(uint256 indexed index, bytes[] publicKeys, bool deferred);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`publicKeys`|`bytes[]`|BLS Public key that got funded|
|`deferred`|`bool`|True if event has been replayed in the context of a migration|

### UpdatedRequestedValidatorExitsUponStopped
The requested exit count has been updated to fill the gap with the reported stopped count


```solidity
event UpdatedRequestedValidatorExitsUponStopped(
    uint256 indexed index, uint32 oldRequestedExits, uint32 newRequestedExits
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`oldRequestedExits`|`uint32`|The old requested exit count|
|`newRequestedExits`|`uint32`|The new requested exit count|

## Errors
### InactiveOperator
The calling operator is inactive


```solidity
error InactiveOperator(uint256 index);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|

### InvalidFundedKeyDeletionAttempt
A funded key deletion has been attempted


```solidity
error InvalidFundedKeyDeletionAttempt();
```

### InvalidUnsortedIndexes
The index provided are not sorted properly (descending order)


```solidity
error InvalidUnsortedIndexes();
```

### InvalidArrayLengths
The provided operator and limits array have different lengths


```solidity
error InvalidArrayLengths();
```

### InvalidEmptyArray
The provided operator and limits array are empty


```solidity
error InvalidEmptyArray();
```

### InvalidKeyCount
The provided key count is 0


```solidity
error InvalidKeyCount();
```

### InvalidKeysLength
The provided concatenated keys do not have the expected length


```solidity
error InvalidKeysLength();
```

### InvalidIndexOutOfBounds
The index that is removed is out of bounds


```solidity
error InvalidIndexOutOfBounds();
```

### OperatorLimitTooHigh
The value for the operator limit is too high


```solidity
error OperatorLimitTooHigh(uint256 index, uint256 limit, uint256 keyCount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`limit`|`uint256`|The new limit provided|
|`keyCount`|`uint256`|The operator key count|

### OperatorLimitTooLow
The value for the limit is too low


```solidity
error OperatorLimitTooLow(uint256 index, uint256 limit, uint256 fundedKeyCount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The operator index|
|`limit`|`uint256`|The new limit provided|
|`fundedKeyCount`|`uint256`|The operator funded key count|

### UnorderedOperatorList
The provided list of operators is not in increasing order


```solidity
error UnorderedOperatorList();
```

### OperatorIgnoredExitRequests
Thrown when an operator ignored the required number of requested exits


```solidity
error OperatorIgnoredExitRequests(uint256 operatorIndex);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operatorIndex`|`uint256`|The operator index|

### OperatorHasInsufficientFundableKeys
Thrown when an operator lacks the required number of fundable keys


```solidity
error OperatorHasInsufficientFundableKeys(uint256 operatorIndex, uint256 requested, uint256 available);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operatorIndex`|`uint256`|The operator index|
|`requested`|`uint256`|The requested count|
|`available`|`uint256`|The available count|

### AllocationWithZeroValidatorCount
Thrown when an allocation with zero validator count is provided


```solidity
error AllocationWithZeroValidatorCount();
```

### InvalidEmptyStoppedValidatorCountsArray
Thrown when an invalid empty stopped validator array is provided


```solidity
error InvalidEmptyStoppedValidatorCountsArray();
```

### InvalidStoppedValidatorCountsSum
Thrown when the sum of stopped validators is invalid


```solidity
error InvalidStoppedValidatorCountsSum();
```

### StoppedValidatorCountsDecreased
Thrown when an element in the stopped validator array is decreasing


```solidity
error StoppedValidatorCountsDecreased();
```

### StoppedValidatorCountsTooHigh
Thrown when the number of elements in the array is too high compared to operator count


```solidity
error StoppedValidatorCountsTooHigh();
```

### NoExitRequestsToPerform
Thrown when no exit requests can be performed


```solidity
error NoExitRequestsToPerform();
```

### StoppedValidatorCountArrayShrinking
The provided stopped validator count array is shrinking


```solidity
error StoppedValidatorCountArrayShrinking();
```

### StoppedValidatorCountAboveFundedCount
The provided stopped validator count of an operator is above its funded validator count


```solidity
error StoppedValidatorCountAboveFundedCount(uint256 operatorIndex, uint32 stoppedCount, uint32 fundedCount);
```

### ExitsRequestedExceedAvailableFundedCount
The provided exit requests exceed the available funded validator count of the operator


```solidity
error ExitsRequestedExceedAvailableFundedCount(uint256 operatorIndex, uint256 requested, uint256 available);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operatorIndex`|`uint256`|The operator index|
|`requested`|`uint256`|The requested count|
|`available`|`uint256`|The available count|

### ExitsRequestedExceedDemand
The provided exit requests exceed the current exit request demand


```solidity
error ExitsRequestedExceedDemand(uint256 requested, uint256 demand);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requested`|`uint256`|The requested count|
|`demand`|`uint256`|The demand count|

## Structs
### OperatorAllocation
Structure representing an operator allocation for deposits or exits


```solidity
struct OperatorAllocation {
    uint256 operatorIndex;
    uint256 validatorCount;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`operatorIndex`|`uint256`|The index of the operator|
|`validatorCount`|`uint256`|The number of validators to deposit/exit for this operator|

