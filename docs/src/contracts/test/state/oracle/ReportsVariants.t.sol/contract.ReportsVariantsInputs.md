# ReportsVariantsInputs
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/state/oracle/ReportsVariants.t.sol)


## Functions
### set


```solidity
function set(uint256 _idx, ReportsVariants.ReportVariantDetails calldata _val) external;
```

### indexOfReport


```solidity
function indexOfReport(bytes32 _variant) external returns (int256);
```

### push


```solidity
function push(ReportsVariants.ReportVariantDetails calldata _variant) external;
```

### getReportAtIndex


```solidity
function getReportAtIndex(uint256 _idx) external returns (ReportsVariants.ReportVariantDetails memory);
```

