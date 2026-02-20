# ReportBounds
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/ReportBounds.sol)

**Title:**
Report Bounds Storage

Utility to manage the Report Bounds in storage


## State Variables
### REPORT_BOUNDS_SLOT
Storage slot of the Report Bounds


```solidity
bytes32 internal constant REPORT_BOUNDS_SLOT = bytes32(uint256(keccak256("river.state.reportBounds")) - 1)
```


## Functions
### get

Retrieve the Report Bounds from storage


```solidity
function get() internal view returns (ReportBoundsStruct memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ReportBoundsStruct`|The Report Bounds|


### set

Set the Report Bounds in storage


```solidity
function set(ReportBoundsStruct memory _newReportBounds) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newReportBounds`|`ReportBoundsStruct`|The new Report Bounds value|


## Structs
### ReportBoundsStruct
The Report Bounds structure


```solidity
struct ReportBoundsStruct {
    /// @custom:attribute The maximum allowed annual apr, checked before submitting a report to River
    uint256 annualAprUpperBound;
    /// @custom:attribute The maximum allowed balance decrease, also checked before submitting a report to River
    uint256 relativeLowerBound;
}
```

### Slot
The structure in storage


```solidity
struct Slot {
    /// @custom:attribute The structure in storage
    ReportBoundsStruct value;
}
```

