# VestingScheduleMigration
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/migration/TLC_globalUnlockScheduleMigration.sol)


```solidity
struct VestingScheduleMigration {
// number of consecutive schedules to migrate with the same parameters
uint8 scheduleCount;
// The new lock duration
uint32 newLockDuration;
// if != 0, the new start value
uint64 newStart;
// if != 0, the new end value
uint64 newEnd;
// set cliff to 0 if true
bool setCliff;
// if true set vesting duration to 86400
bool setDuration;
// if true set vesting period duration to 86400
bool setPeriodDuration;
// if true schedule will not be subject to global unlock schedule
bool ignoreGlobalUnlock;
}
```

