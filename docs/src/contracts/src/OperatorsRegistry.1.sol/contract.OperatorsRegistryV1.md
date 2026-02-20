# OperatorsRegistryV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/OperatorsRegistry.1.sol)

**Inherits:**
[IOperatorsRegistryV1](/contracts/src/interfaces/IOperatorRegistry.1.sol/interface.IOperatorsRegistryV1.md), [Initializable](/contracts/src/Initializable.sol/contract.Initializable.md), [Administrable](/contracts/src/Administrable.sol/abstract.Administrable.md), [IProtocolVersion](/contracts/src/interfaces/IProtocolVersion.sol/interface.IProtocolVersion.md)

**Title:**
Operators Registry (v1)

**Author:**
Alluvial Finance Inc.

This contract handles the list of operators and their keys

Operator index is the position in the operators array. Operators are only

added, never removed, so the operator at index i is always the one at

array position i and indices are stable over time.


## Functions
### initOperatorsRegistryV1

Initializes the operators registry


```solidity
function initOperatorsRegistryV1(address _admin, address _river) external init(0);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Admin in charge of managing operators|
|`_river`|`address`|Address of River system|


### _migrateOperators_V1_1

Internal migration utility to migrate all operators to OperatorsV2 format


```solidity
function _migrateOperators_V1_1() internal;
```

### forceFundedValidatorKeysEventEmission

Utility to force the broadcasting of events. Will keep its progress in storage to prevent being DoSed by the number of keys


```solidity
function forceFundedValidatorKeysEventEmission(uint256 _amountToEmit) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amountToEmit`|`uint256`|The amount of events to emit at maximum in this call|


### initOperatorsRegistryV1_1

Initializes the operators registry for V1_1


```solidity
function initOperatorsRegistryV1_1() external init(1);
```

### onlyRiver

Prevent unauthorized calls


```solidity
modifier onlyRiver() virtual;
```

### onlyOperatorOrAdmin

Prevents anyone except the admin or the given operator to make the call. Also checks if operator is active

The admin is able to call this method on behalf of any operator, even if inactive


```solidity
modifier onlyOperatorOrAdmin(uint256 _index) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The index identifying the operator|


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


```solidity
function getTotalValidatorExitsRequested() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total requested exit count|


### getCurrentValidatorExitsDemand

Get the current exit request demand waiting to be triggered


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
|`<none>`|`uint256`||


### getOperatorCount

Get operator count


```solidity
function getOperatorCount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The operator count|


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


```solidity
function reportStoppedValidatorCounts(uint32[] calldata _stoppedValidatorCounts, uint256 _depositedValidatorCount)
    external
    onlyRiver;
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
function addOperator(string calldata _name, address _operator) external onlyAdmin returns (uint256);
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
function setOperatorAddress(uint256 _index, address _newOperatorAddress) external onlyOperatorOrAdmin(_index);
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
function setOperatorName(uint256 _index, string calldata _newName) external onlyOperatorOrAdmin(_index);
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
function setOperatorStatus(uint256 _index, bool _newStatus) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The operator index|
|`_newStatus`|`bool`|The new status of the operator|


### setOperatorLimits

Changes the operator staking limit

Only callable by the administrator


```solidity
function setOperatorLimits(
    uint256[] calldata _operatorIndexes,
    uint32[] calldata _newLimits,
    uint256 _snapshotBlock
) external onlyAdmin;
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
function addValidators(uint256 _index, uint32 _keyCount, bytes calldata _publicKeysAndSignatures)
    external
    onlyOperatorOrAdmin(_index);
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


```solidity
function removeValidators(uint256 _index, uint256[] calldata _indexes) external onlyOperatorOrAdmin(_index);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The operator index|
|`_indexes`|`uint256[]`|The indexes of the keys to remove|


### pickNextValidatorsToDeposit

Retrieve validator keys based on explicit operator allocations and mark them as funded

Only callable by the river contract


```solidity
function pickNextValidatorsToDeposit(OperatorAllocation[] calldata _allocations)
    external
    onlyRiver
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
function demandValidatorExits(uint256 _count, uint256 _depositedValidatorCount) external onlyRiver;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_count`|`uint256`|The amount of exit requests to add to the demand|
|`_depositedValidatorCount`|`uint256`|The total deposited validator count|


### _getFundedCountForOperatorIfFundable

Internal utility to get the funded count for an active operator if it is fundable


```solidity
function _getFundedCountForOperatorIfFundable(uint256 _operatorIndex, uint256 _validatorCount)
    internal
    view
    returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operatorIndex`|`uint256`|The operator index|
|`_validatorCount`|`uint256`|The validator count|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|fundedCount The funded count of the operator|


### _getPerOperatorValidatorKeysForAllocations

Internal view utility that retrieves the validator keys for the given allocations


```solidity
function _getPerOperatorValidatorKeysForAllocations(OperatorAllocation[] memory _allocations)
    internal
    view
    returns (bytes[][] memory perOperatorKeys, bytes[][] memory perOperatorSigs);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_allocations`|`OperatorAllocation[]`|The operator allocations sorted by operator index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`perOperatorKeys`|`bytes[][]`|Per-operator arrays of public keys|
|`perOperatorSigs`|`bytes[][]`|Per-operator arrays of signatures|


### _getTotalStoppedValidatorCount

Internal utility to retrieve the total stopped validator count


```solidity
function _getTotalStoppedValidatorCount() internal view returns (uint32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The total stopped validator count|


### _setCurrentValidatorExitsDemand

Internal utility to set the current validator exits demand


```solidity
function _setCurrentValidatorExitsDemand(uint256 _currentValue, uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_currentValue`|`uint256`|The current value|
|`_newValue`|`uint256`|The new value|


### _setStoppedValidatorCounts

Internal utility to set the stopped validator array after sanity checks


```solidity
function _setStoppedValidatorCounts(uint32[] calldata _stoppedValidatorCounts, uint256 _depositedValidatorCount)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stoppedValidatorCounts`|`uint32[]`|The stopped validators counts for every operator + the total count in index 0|
|`_depositedValidatorCount`|`uint256`|The current deposited validator count|


### _flattenByteArrays

Internal utility to flatten a 2D bytes array into a 1D bytes array with a single allocation


```solidity
function _flattenByteArrays(bytes[][] memory _arrays) internal pure returns (bytes[] memory result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_arrays`|`bytes[][]`|The 2D array to flatten|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`bytes[]`|The flattened 1D array|


### _getStoppedValidatorsCount

Internal utility to retrieve the actual stopped validator count of an operator from the reported array


```solidity
function _getStoppedValidatorsCount(uint256 _operatorIndex) internal view returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operatorIndex`|`uint256`|The operator index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The count of stopped validators|


### _setTotalValidatorExitsRequested

Internal utility to set the total validator exits requested by the system


```solidity
function _setTotalValidatorExitsRequested(uint256 _currentValue, uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_currentValue`|`uint256`|The current value of the total validator exits requested|
|`_newValue`|`uint256`|The new value of the total validator exits requested|


### version

Retrieves the version of the contract


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Version of the contract|


## Errors
### FundedKeyEventMigrationComplete
MIGRATION: FUNDED VALIDATOR KEY EVENT REBROADCASTING
As the event for funded keys was moved from River to this contract because we needed to be able to bind
operator indexes to public keys, we need to rebroadcast the past funded validator keys with the new event
to keep retro-compatibility
Emitted when the event rebroadcasting is done and we attempt to broadcast new events


```solidity
error FundedKeyEventMigrationComplete();
```

## Structs
### SetStoppedValidatorCountInternalVars
Internal structure to hold variables for the _setStoppedValidatorCounts method


```solidity
struct SetStoppedValidatorCountInternalVars {
    uint256 stoppedValidatorCountsLength;
    uint32[] currentStoppedValidatorCounts;
    uint256 currentStoppedValidatorCountsLength;
    uint32 totalStoppedValidatorCount;
    uint32 count;
    uint256 currentValidatorExitsDemand;
    uint256 cachedCurrentValidatorExitsDemand;
    uint256 totalRequestedExits;
    uint256 cachedTotalRequestedExits;
}
```

