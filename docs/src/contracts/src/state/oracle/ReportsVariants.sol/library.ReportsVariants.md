# ReportsVariants
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/oracle/ReportsVariants.sol)

**Title:**
Reports Variants Storage

Utility to manage the Reports Variants in storage


## State Variables
### REPORT_VARIANTS_SLOT
Storage slot of the Reports Variants


```solidity
bytes32 internal constant REPORT_VARIANTS_SLOT = bytes32(uint256(keccak256("river.state.reportsVariants")) - 1)
```


## Functions
### get

Retrieve the Reports Variants from storage


```solidity
function get() internal view returns (ReportVariantDetails[] storage);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ReportVariantDetails[]`|The Reports Variants|


### set

Set the Reports Variants value at index


```solidity
function set(uint256 _idx, ReportVariantDetails memory _val) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_idx`|`uint256`|The index to set|
|`_val`|`ReportVariantDetails`|The value to set|


### push

Add a new variant in the list


```solidity
function push(ReportVariantDetails memory _variant) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_variant`|`ReportVariantDetails`|The new variant to add|


### indexOfReport

Retrieve the index of a specific variant, ignoring the count field


```solidity
function indexOfReport(bytes32 _variant) internal view returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_variant`|`bytes32`|Variant value to lookup|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The index of the variant, -1 if not found|


### clear

Clear all variants from storage


```solidity
function clear() internal;
```

## Structs
### ReportVariantDetails

```solidity
struct ReportVariantDetails {
    bytes32 variant;
    uint256 votes;
}
```

### Slot
Structure in storage


```solidity
struct Slot {
    /// @custom:attribute The list of variants
    ReportVariantDetails[] value;
}
```

