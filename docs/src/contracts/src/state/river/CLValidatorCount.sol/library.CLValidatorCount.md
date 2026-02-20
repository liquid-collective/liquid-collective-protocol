# CLValidatorCount
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/CLValidatorCount.sol)

**Title:**
Consensus Layer Validator Count Storage

Utility to manage the Consensus Layer Validator Count in storage

This state variable is deprecated and was kept due to migration logic needs


## State Variables
### CL_VALIDATOR_COUNT_SLOT
Storage slot of the Consensus Layer Validator Count


```solidity
bytes32 internal constant CL_VALIDATOR_COUNT_SLOT = bytes32(uint256(keccak256("river.state.clValidatorCount")) - 1)
```


## Functions
### get

Retrieve the Consensus Layer Validator Count


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Consensus Layer Validator Count|


### set

Sets the Consensus Layer Validator Count


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New Consensus Layer Validator Count|


