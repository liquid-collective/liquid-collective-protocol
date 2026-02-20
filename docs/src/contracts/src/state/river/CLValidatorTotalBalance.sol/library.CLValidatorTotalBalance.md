# CLValidatorTotalBalance
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/CLValidatorTotalBalance.sol)

**Title:**
Consensus Layer Validator Total Balance Storage

Utility to manage the Consensus Layer Validator Total Balance in storage

This state variable is deprecated and was kept due to migration logic needs


## State Variables
### CL_VALIDATOR_TOTAL_BALANCE_SLOT
Storage slot of the Consensus Layer Validator Total Balance


```solidity
bytes32 internal constant CL_VALIDATOR_TOTAL_BALANCE_SLOT =
    bytes32(uint256(keccak256("river.state.clValidatorTotalBalance")) - 1)
```


## Functions
### get

Retrieve the Consensus Layer Validator Total Balance


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Consensus Layer Validator Total Balance|


### set

Sets the Consensus Layer Validator Total Balance


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New Consensus Layer Validator Total Balance|


