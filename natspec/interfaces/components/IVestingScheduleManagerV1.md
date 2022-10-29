# IVestingScheduleManagerV1

*Alluvial*

> Vesting Schedules Interface (v1)

This interface exposes methods to manage vestings



## Methods

### computeVestingReleasableAmount

```solidity
function computeVestingReleasableAmount(uint256 _index) external view returns (uint256)
```

Computes the releasable amount of tokens for a vesting schedule.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | index of the vesting schedule |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of release tokens |

### createVestingSchedule

```solidity
function createVestingSchedule(uint64 _start, uint32 _cliffDuration, uint32 _duration, uint32 _period, uint32 _lockDuration, bool _revocable, uint256 _amount, address _beneficiary, address _delegatee) external nonpayable returns (uint256)
```

Creates a new vesting schedule



#### Parameters

| Name | Type | Description |
|---|---|---|
| _start | uint64 | start time of the vesting |
| _cliffDuration | uint32 | duration to vesting cliff (in seconds) |
| _duration | uint32 | total vesting schedule duration after which all tokens are vested (in seconds) |
| _period | uint32 | duration of a period after which new tokens unlock (in seconds) |
| _lockDuration | uint32 | duration during which tokens are locked (in seconds) |
| _revocable | bool | whether the vesting schedule is revocable or not |
| _amount | uint256 | amount of token attributed by the vesting schedule |
| _beneficiary | address | address of the beneficiary of the tokens |
| _delegatee | address | address to delegate escrow voting power to |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | index of the created vesting schedule |

### delegateVestingEscrow

```solidity
function delegateVestingEscrow(uint256 _index, address _delegatee) external nonpayable returns (bool)
```

Delegate vesting escrowed tokens



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | index of the vesting schedule |
| _delegatee | address | address to delegate the token to |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### getVestingSchedule

```solidity
function getVestingSchedule(uint256 _index) external view returns (struct VestingSchedules.VestingSchedule)
```

Get vesting schedule



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | Index of the vesting schedule |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | VestingSchedules.VestingSchedule | undefined |

### getVestingScheduleCount

```solidity
function getVestingScheduleCount() external view returns (uint256)
```

Get count of vesting schedules




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | count of vesting schedules |

### releaseVestingSchedule

```solidity
function releaseVestingSchedule(uint256 _index) external nonpayable returns (uint256)
```

Release vesting schedule



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | Index of the vesting schedule to release |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | released amount |

### revokeVestingSchedule

```solidity
function revokeVestingSchedule(uint256 _index, uint64 _end) external nonpayable returns (uint256 returnedAmount)
```

Revoke vesting schedule



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | Index of the vesting schedule to revoke |
| _end | uint64 | End date for the schedule |

#### Returns

| Name | Type | Description |
|---|---|---|
| returnedAmount | uint256 | amount returned to the vesting schedule creator |

### vestingEscrow

```solidity
function vestingEscrow(uint256 _index) external view returns (address)
```

Get the address of the escrow for a vesting schedule



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | Index of the vesting schedule |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | address of the escrow |



## Events

### CreatedVestingSchedule

```solidity
event CreatedVestingSchedule(uint256 index, address indexed creator, address indexed beneficiary, uint256 amount)
```

A new vesting schedule has been created



#### Parameters

| Name | Type | Description |
|---|---|---|
| index  | uint256 | Vesting schedule index |
| creator `indexed` | address | Creator of the vesting schedule |
| beneficiary `indexed` | address | Vesting beneficiary address |
| amount  | uint256 | Vesting schedule amount |

### DelegatedVestingEscrow

```solidity
event DelegatedVestingEscrow(uint256 index, address oldDelegatee, address newDelegatee)
```

Vesting escrow has been delegated



#### Parameters

| Name | Type | Description |
|---|---|---|
| index  | uint256 | Vesting schedule index |
| oldDelegatee  | address | old delegatee |
| newDelegatee  | address | new delegatee |

### ReleasedVestingSchedule

```solidity
event ReleasedVestingSchedule(uint256 index, uint256 releasedAmount)
```

Vesting schedule has been released



#### Parameters

| Name | Type | Description |
|---|---|---|
| index  | uint256 | Vesting schedule index |
| releasedAmount  | uint256 | Amount of tokens released to the beneficiary |

### RevokedVestingSchedule

```solidity
event RevokedVestingSchedule(uint256 index, uint256 returnedAmount)
```

Vesting schedule has been revoked



#### Parameters

| Name | Type | Description |
|---|---|---|
| index  | uint256 | Vesting schedule index |
| returnedAmount  | uint256 | Amount of tokens returned to the creator |



## Errors

### InvalidRevokedVestingScheduleEnd

```solidity
error InvalidRevokedVestingScheduleEnd()
```

Attempt to revoke at a




### InvalidVestingScheduleParameter

```solidity
error InvalidVestingScheduleParameter(string msg)
```

Invalid parameter for a vesting schedule



#### Parameters

| Name | Type | Description |
|---|---|---|
| msg | string | undefined |

### UnsufficientVestingScheduleCreatorBalance

```solidity
error UnsufficientVestingScheduleCreatorBalance()
```

Vesting schedule creator has unsufficient balance to create vesting schedule




### VestingScheduleIsLocked

```solidity
error VestingScheduleIsLocked()
```

The vesting schedule is locked




### VestingScheduleNotRevocable

```solidity
error VestingScheduleNotRevocable()
```

The vesting schedule is not revocable




### VestingScheduleNotRevocableInPast

```solidity
error VestingScheduleNotRevocableInPast()
```

Attempt to revoke a schedule in the past




### ZeroReleasableAmount

```solidity
error ZeroReleasableAmount()
```

No token to release





