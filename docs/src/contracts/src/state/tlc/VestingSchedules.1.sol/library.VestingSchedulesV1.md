# VestingSchedulesV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/tlc/VestingSchedules.1.sol)

**Title:**
VestingSchedulesV1 Storage

Utility to manage VestingSchedulesV1 in storage


## State Variables
### VESTING_SCHEDULES_SLOT
Storage slot of the Vesting Schedules


```solidity
bytes32 internal constant VESTING_SCHEDULES_SLOT =
    bytes32(uint256(keccak256("erc20VestableVotes.state.schedules")) - 1)
```


## Functions
### get

Retrieve the vesting schedule in storage


```solidity
function get(uint256 _index) internal view returns (VestingSchedule storage);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|index of the vesting schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`VestingSchedule`|the vesting schedule|


### getCount

Get vesting schedule count in storage


```solidity
function getCount() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The count of vesting schedule in storage|


### push

Add a new vesting schedule in storage


```solidity
function push(VestingSchedule memory _newSchedule) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newSchedule`|`VestingSchedule`|new vesting schedule to create|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The size of the vesting schedule array after the operation|


## Errors
### VestingScheduleNotFound
The VestingSchedule was not found


```solidity
error VestingScheduleNotFound(uint256 index);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|vesting schedule index|

## Structs
### VestingSchedule

```solidity
struct VestingSchedule {
    // start time of the vesting period
    uint64 start;
    // date at which the vesting is ended
    // initially it is equal to start+duration then to revoke date in case of revoke
    uint64 end;
    // duration before which first tokens gets ownable
    uint32 cliffDuration;
    // duration before tokens gets unlocked. can exceed the duration of the vesting chedule
    uint32 lockDuration;
    // duration of the entire vesting (sum of all vesting period durations)
    uint32 duration;
    // duration of a single period of vesting
    uint32 periodDuration;
    // amount of tokens granted by the vesting schedule
    uint256 amount;
    // creator of the token vesting
    address creator;
    // beneficiary of tokens after they are releaseVestingScheduled
    address beneficiary;
    // whether the schedule can be revoked
    bool revocable;
}
```

### SlotVestingSchedule
The structure at the storage slot


```solidity
struct SlotVestingSchedule {
    /// @custom:attribute Array containing all the vesting schedules
    VestingSchedule[] value;
}
```

