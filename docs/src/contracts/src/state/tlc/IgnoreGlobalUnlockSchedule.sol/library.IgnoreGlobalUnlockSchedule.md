# IgnoreGlobalUnlockSchedule
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/tlc/IgnoreGlobalUnlockSchedule.sol)

**Title:**
Global unlock schedule activation storage

Utility to manage the global unlock schedule activation mapping in storage

The global unlock schedule releases 1/24th of the total scheduled amount every month after the local lock end


## State Variables
### GLOBAL_UNLOCK_ACTIVATION_SLOT
Storage slot of the global unlock schedule activation mapping


```solidity
bytes32 internal constant GLOBAL_UNLOCK_ACTIVATION_SLOT =
    bytes32(uint256(keccak256("tlc.state.globalUnlockScheduleActivation")) - 1)
```


## Functions
### get

Retrieve the global unlock schedule activation value of a schedule, true if the global lock should be ignored


```solidity
function get(uint256 _scheduleId) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_scheduleId`|`uint256`|The schedule id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|The global unlock activation value|


### set

Sets the global unlock schedule activation value of a schedule


```solidity
function set(uint256 _scheduleId, bool _ignoreGlobalUnlock) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_scheduleId`|`uint256`|The id of the schedule to modify|
|`_ignoreGlobalUnlock`|`bool`|The value to set, true if the global lock should be ignored|


## Structs
### Slot
Structure stored in storage slot


```solidity
struct Slot {
    /// @custom:attribute Mapping keeping track of activation per schedule
    mapping(uint256 => bool) value;
}
```

