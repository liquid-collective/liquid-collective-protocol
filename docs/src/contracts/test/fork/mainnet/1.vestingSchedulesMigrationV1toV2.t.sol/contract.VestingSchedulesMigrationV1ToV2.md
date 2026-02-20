# VestingSchedulesMigrationV1ToV2
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/fork/mainnet/1.vestingSchedulesMigrationV1toV2.t.sol)

**Inherits:**
Test


## State Variables
### _skip

```solidity
bool internal _skip = false
```


### TLC_MAINNET_ADDRESS

```solidity
address internal constant TLC_MAINNET_ADDRESS = 0xb5Fe6946836D687848B5aBd42dAbF531d5819632
```


### TLC_MAINNET_PROXY_ADMIN_ADDRESS

```solidity
address internal constant TLC_MAINNET_PROXY_ADMIN_ADDRESS = 0x0D1dE267015a75F5069fD1c9ed382210B3002cEb
```


## Functions
### setUp


```solidity
function setUp() external;
```

### shouldSkip


```solidity
modifier shouldSkip() ;
```

### test_migration


```solidity
function test_migration() external shouldSkip;
```

### getExpectedVestingSchedules


```solidity
function getExpectedVestingSchedules() internal pure returns (VestingSchedulesV2.VestingSchedule[] memory vs);
```

