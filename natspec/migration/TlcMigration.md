# TlcMigration









## Methods

### migrate

```solidity
function migrate() external nonpayable
```









## Errors

### CliffTooLong

```solidity
error CliffTooLong(uint256 i)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| i | uint256 | undefined |

### VestingScheduleNotFound

```solidity
error VestingScheduleNotFound(uint256 index)
```

The VestingSchedule was not found



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | vesting schedule index |

### WrongEnd

```solidity
error WrongEnd(uint256 i)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| i | uint256 | undefined |

### WrongUnlockDate

```solidity
error WrongUnlockDate(uint256 i)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| i | uint256 | undefined |


