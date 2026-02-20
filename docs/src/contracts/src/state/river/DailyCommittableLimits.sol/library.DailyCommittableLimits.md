# DailyCommittableLimits
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/DailyCommittableLimits.sol)

**Title:**
Daily Committable Limits storage

Utility to manage the Daily Committable Limits in storage


## State Variables
### DAILY_COMMITTABLE_LIMITS_SLOT
Storage slot of the Daily Committable Limits storage


```solidity
bytes32 internal constant DAILY_COMMITTABLE_LIMITS_SLOT =
    bytes32(uint256(keccak256("river.state.dailyCommittableLimits")) - 1)
```


## Functions
### get

Retrieve the Daily Committable Limits from storage


```solidity
function get() internal view returns (DailyCommittableLimitsStruct memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`DailyCommittableLimitsStruct`|The Daily Committable Limits|


### set

Set the Daily Committable Limits value in storage


```solidity
function set(DailyCommittableLimitsStruct memory _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`DailyCommittableLimitsStruct`|The new value to set in storage|


## Structs
### DailyCommittableLimitsStruct
The daily committable limits structure


```solidity
struct DailyCommittableLimitsStruct {
    uint128 minDailyNetCommittableAmount;
    uint128 maxDailyRelativeCommittableAmount;
}
```

### Slot
The structure in storage


```solidity
struct Slot {
    /// @custom:attribute The structure in storage
    DailyCommittableLimitsStruct value;
}
```

