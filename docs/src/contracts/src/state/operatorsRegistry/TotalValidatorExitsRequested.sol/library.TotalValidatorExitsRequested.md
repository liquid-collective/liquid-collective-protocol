# TotalValidatorExitsRequested
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/operatorsRegistry/TotalValidatorExitsRequested.sol)

**Title:**
TotalValidatorExitsRequested Storage

This value is the amount of performed exit requests, only increased when there is current exit demand

Utility to manage the TotalValidatorExitsRequested in storage


## State Variables
### TOTAL_VALIDATOR_EXITS_REQUESTED_SLOT
Storage slot of the TotalValidatorExitsRequested


```solidity
bytes32 internal constant TOTAL_VALIDATOR_EXITS_REQUESTED_SLOT =
    bytes32(uint256(keccak256("river.state.totalValidatorExitsRequested")) - 1)
```


## Functions
### get

Retrieve the TotalValidatorExitsRequested


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The TotalValidatorExitsRequested|


### set

Sets the TotalValidatorExitsRequested


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New TotalValidatorExitsRequested|


