# CurrentValidatorExitsDemand
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/operatorsRegistry/CurrentValidatorExitsDemand.sol)

**Title:**
CurrentValidatorExitsDemand Storage

This value controls the current demand for exits that still need to be triggered

in order to notify the operators

Utility to manage the CurrentValidatorExitsDemand in storage


## State Variables
### CURRENT_VALIDATOR_EXITS_DEMAND_SLOT
Storage slot of the CurrentValidatorExitsDemand


```solidity
bytes32 internal constant CURRENT_VALIDATOR_EXITS_DEMAND_SLOT =
    bytes32(uint256(keccak256("river.state.currentValidatorExitsDemand")) - 1)
```


## Functions
### get

Retrieve the CurrentValidatorExitsDemand


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The CurrentValidatorExitsDemand|


### set

Sets the CurrentValidatorExitsDemand


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New CurrentValidatorExitsDemand|


