# BalanceForCoverage
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/slashingCoverage/BalanceForCoverage.sol)

**Title:**
Balance For Coverage Value Storage

Utility to manage the Balance For Coverrage value in storage


## State Variables
### BALANCE_FOR_COVERAGE_SLOT
Storage slot of the Balance For Coverage Address


```solidity
bytes32 internal constant BALANCE_FOR_COVERAGE_SLOT =
    bytes32(uint256(keccak256("river.state.balanceForCoverage")) - 1)
```


## Functions
### get

Get the Balance for Coverage value


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance for coverage value|


### set

Sets the Balance for Coverage value


```solidity
function set(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|New Balance for Coverage value|


