# DepositedValidatorCount
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/DepositedValidatorCount.sol)

**Title:**
Deposited Validator Count Storage

Utility to manage the Deposited Validator Count in storage


## State Variables
### DEPOSITED_VALIDATOR_COUNT_SLOT
Storage slot of the Deposited Validator Count


```solidity
bytes32 internal constant DEPOSITED_VALIDATOR_COUNT_SLOT =
    bytes32(uint256(keccak256("river.state.depositedValidatorCount")) - 1)
```


## Functions
### get

Retrieve the Deposited Validator Count


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Deposited Validator Count|


### set

Sets the Deposited Validator Count


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New Deposited Validator Count|


