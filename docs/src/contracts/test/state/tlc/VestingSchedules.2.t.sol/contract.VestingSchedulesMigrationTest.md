# VestingSchedulesMigrationTest
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/state/tlc/VestingSchedules.2.t.sol)

**Inherits:**
Test


## State Variables
### alice

```solidity
address internal alice
```


### bob

```solidity
address internal bob
```


## Functions
### setUp


```solidity
function setUp() public;
```

### _createV1VestingSchedule


```solidity
function _createV1VestingSchedule(VestingSchedulesV1.VestingSchedule memory vestingSchedule)
    internal
    returns (uint256);
```

### _updateV2VestingSchedule


```solidity
function _updateV2VestingSchedule(uint256 index, VestingSchedulesV2.VestingSchedule memory newVestingSchedule)
    internal
    returns (bool);
```

### _migrate


```solidity
function _migrate() internal returns (uint256);
```

### getV1Schedule

External wrapper to call VestingSchedulesV1.get so vm.expectRevert can catch it


```solidity
function getV1Schedule(uint256 _index) external view returns (VestingSchedulesV1.VestingSchedule memory);
```

### getV2Schedule

External wrapper to call VestingSchedulesV2.get so vm.expectRevert can catch it


```solidity
function getV2Schedule(uint256 _index) external view returns (VestingSchedulesV2.VestingSchedule memory);
```

### testGetRevert


```solidity
function testGetRevert() public;
```

### testVestingScheduleV1ToV2Compatibility


```solidity
function testVestingScheduleV1ToV2Compatibility(
    uint64 _start,
    uint64 _end,
    uint32 _duration,
    uint32 _periodDuration,
    uint32 _cliffDuration,
    uint32 _lockDuration,
    bool _revocable,
    uint256 _amount,
    uint256 _releasedAmount
) public;
```

