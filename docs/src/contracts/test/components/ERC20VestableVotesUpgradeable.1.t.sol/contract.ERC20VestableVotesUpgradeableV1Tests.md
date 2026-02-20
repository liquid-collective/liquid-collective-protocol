# ERC20VestableVotesUpgradeableV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ERC20VestableVotesUpgradeable.1.t.sol)

**Inherits:**
Test


## State Variables
### tt

```solidity
TestToken internal tt
```


### escrowImplem

```solidity
address internal escrowImplem
```


### initAccount

```solidity
address internal initAccount
```


### bob

```solidity
address internal bob
```


### joe

```solidity
address internal joe
```


### alice

```solidity
address internal alice
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testTransfer


```solidity
function testTransfer() public;
```

### testDelegate


```solidity
function testDelegate() public;
```

### testCheckpoints


```solidity
function testCheckpoints() public;
```

### testDelegateAndTransfer


```solidity
function testDelegateAndTransfer() public;
```

### createVestingSchedule


```solidity
function createVestingSchedule(
    address beneficiary,
    uint256 start,
    uint256 cliffDuration,
    uint256 duration,
    uint256 period,
    uint256 lockDuration,
    bool revocable,
    uint256 amount
) internal returns (uint256);
```

### createVestingScheduleWithGlobalUnlock


```solidity
function createVestingScheduleWithGlobalUnlock(
    address beneficiary,
    uint256 start,
    uint256 cliffDuration,
    uint256 duration,
    uint256 period,
    uint256 lockDuration,
    bool revocable,
    uint256 amount
) internal returns (uint256);
```

### createVestingSchedulesV2tackOptimized


```solidity
function createVestingSchedulesV2tackOptimized(
    uint64 start,
    uint32 cliffDuration,
    uint32 duration,
    uint32 period,
    uint32 lockDuration,
    uint256 amount,
    address beneficiary,
    bool revocable,
    bool ignoreGlobalUnlockSchedule
) internal returns (uint256);
```

### testCreateVesting


```solidity
function testCreateVesting() public;
```

### testCreateVestingWithGlobalUnlock


```solidity
function testCreateVestingWithGlobalUnlock() public;
```

### testCreateVestingWithDelegatee


```solidity
function testCreateVestingWithDelegatee() public;
```

### testCreateInvalidVestingZeroBeneficiary


```solidity
function testCreateInvalidVestingZeroBeneficiary() public;
```

### testCreateInvalidVestingAmountTooLowForPeriodAndDuration


```solidity
function testCreateInvalidVestingAmountTooLowForPeriodAndDuration() public;
```

### testCreateInvalidVestingZeroDuration


```solidity
function testCreateInvalidVestingZeroDuration() public;
```

### testCreateInvalidVestingZeroAmount


```solidity
function testCreateInvalidVestingZeroAmount() public;
```

### testCreateInvalidVestingZeroPeriod


```solidity
function testCreateInvalidVestingZeroPeriod() public;
```

### testCreateInvalidVestingPeriodDoesNotDivideDuration


```solidity
function testCreateInvalidVestingPeriodDoesNotDivideDuration() public;
```

### testCreateInvalidVestingPeriodDoesNotDivideCliffDuration


```solidity
function testCreateInvalidVestingPeriodDoesNotDivideCliffDuration() public;
```

### testCreateMultipleVestings


```solidity
function testCreateMultipleVestings() public;
```

### testCreateVestingDefaultStart


```solidity
function testCreateVestingDefaultStart(uint40 start) public;
```

### testReleaseVestingScheduleBeforeCliff


```solidity
function testReleaseVestingScheduleBeforeCliff() public;
```

### testReleaseVestingScheduleAfterCliffButBeforeLock


```solidity
function testReleaseVestingScheduleAfterCliffButBeforeLock() public;
```

### testReleaseVestingScheduleAtLockDuration


```solidity
function testReleaseVestingScheduleAtLockDuration() public;
```

### testReleaseVestingScheduleAfterLockDuration


```solidity
function testReleaseVestingScheduleAfterLockDuration() public;
```

### testcomputeVestingAmounts


```solidity
function testcomputeVestingAmounts() public;
```

### testcomputeVestingAmountsWithGlobalUnlockSchedule


```solidity
function testcomputeVestingAmountsWithGlobalUnlockSchedule() public;
```

### testReleaseVestingScheduleAfterVestingBeforeGlobalUnlock


```solidity
function testReleaseVestingScheduleAfterVestingBeforeGlobalUnlock() public;
```

### testReleaseVestingScheduleFromInvalidAccount


```solidity
function testReleaseVestingScheduleFromInvalidAccount() public;
```

### testRevokeBeforeCliff


```solidity
function testRevokeBeforeCliff() public;
```

### testRevokeAtCliff


```solidity
function testRevokeAtCliff() public;
```

### testRevokeAtDuration


```solidity
function testRevokeAtDuration() public;
```

### testRevokeDefault


```solidity
function testRevokeDefault() public;
```

### testRevokeNotRevokable


```solidity
function testRevokeNotRevokable() public;
```

### testRevokeFromInvalidAccount


```solidity
function testRevokeFromInvalidAccount() public;
```

### testRevokeTwice


```solidity
function testRevokeTwice() public;
```

### testRevokeTwiceAfterEnd


```solidity
function testRevokeTwiceAfterEnd() public;
```

### testReleaseVestingScheduleAfterRevoke


```solidity
function testReleaseVestingScheduleAfterRevoke() public;
```

### testDelegateVestingEscrow


```solidity
function testDelegateVestingEscrow() public;
```

### testDelegateVestingEscrowFromInvalidAccount


```solidity
function testDelegateVestingEscrowFromInvalidAccount() public;
```

### testVestingScheduleFuzzing


```solidity
function testVestingScheduleFuzzing(
    uint24 periodDuration,
    uint32 lockDuration,
    uint8 cliffPeriodCount,
    uint8 vestingPeriodCount,
    uint256 amount,
    uint256 releaseAt,
    uint256 revokeAt
) public;
```

### testDOSReleaseVestingSchedule


```solidity
function testDOSReleaseVestingSchedule() public;
```

### testDOSRevokeVestingSchedule


```solidity
function testDOSRevokeVestingSchedule() public;
```

### testDOSComputeVestingReleasableAmount


```solidity
function testDOSComputeVestingReleasableAmount() public;
```

### testRevokeRevertsPastEndDate


```solidity
function testRevokeRevertsPastEndDate() public;
```

### testRevokeIfCliffDurationGreaterThanDuration


```solidity
function testRevokeIfCliffDurationGreaterThanDuration() public;
```

## Events
### CreatedVestingSchedule

```solidity
event CreatedVestingSchedule(uint256 index, address indexed creator, address indexed beneficiary, uint256 amount);
```

### ReleasedVestingSchedule

```solidity
event ReleasedVestingSchedule(uint256 index, uint256 releasedAmount);
```

### RevokedVestingSchedule

```solidity
event RevokedVestingSchedule(uint256 index, uint256 returnedAmount, uint256 newEnd);
```

### DelegatedVestingEscrow

```solidity
event DelegatedVestingEscrow(
    uint256 index, address indexed oldDelegatee, address indexed newDelegatee, address indexed beneficiary
);
```

## Structs
### VestingSchedule

```solidity
struct VestingSchedule {
    uint256 start;
    uint256 cliffDuration;
    uint256 lockDuration;
    uint256 duration;
    uint256 period;
    uint256 amount;
    address beneficiary;
    address delegatee;
    bool revocable;
}
```

