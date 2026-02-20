# CoverageFundAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/CoverageFundAddress.sol)

**Title:**
Coverage Fund Address Storage

Utility to manage the Coverage Fund Address in storage


## State Variables
### COVERAGE_FUND_ADDRESS_SLOT
Storage slot of the Coverage Fund Address


```solidity
bytes32 internal constant COVERAGE_FUND_ADDRESS_SLOT =
    bytes32(uint256(keccak256("river.state.coverageFundAddress")) - 1)
```


## Functions
### get

Retrieve the Coverage Fund Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Coverage Fund Address|


### set

Sets the Coverage Fund Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Coverage Fund Address|


