# IERC20VestableVotesUpgradeableV1

*Alluvial Finance Inc.*

> ERC20 Vestable Votes Upgradeable Interface(v1)

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
| _0 | uint256 | amount of releasable tokens |

### computeVestingVestedAmount

```solidity
function computeVestingVestedAmount(uint256 _index) external view returns (uint256)
```

Computes the vested amount of tokens for a vesting schedule.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | index of the vesting schedule |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of vested tokens |

### createVestingSchedule

```solidity
function createVestingSchedule(uint64 _start, uint32 _cliffDuration, uint32 _duration, uint32 _periodDuration, uint32 _lockDuration, bool _revocable, uint256 _amount, address _beneficiary, address _delegatee, bool _ignoreGlobalUnlockSchedule) external nonpayable returns (uint256)
```

Creates a new vesting scheduleThere may delay between the time a user should start vesting tokens and the time the vesting schedule is actually created on the contract.Typically a user joins the Liquid Collective but some weeks pass before the user gets all legal agreements in place and signed for thetoken grant emission to happen. In this case, the vesting schedule created for the token grant would start on the join date which is in the past.

*As vesting schedules can be created in the past, this means that you should be careful when creating a vesting schedule and what duration parametersyou use as this contract would allow creating a vesting schedule in the past and even a vesting schedule that has already ended.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _start | uint64 | start time of the vesting |
| _cliffDuration | uint32 | duration to vesting cliff (in seconds) |
| _duration | uint32 | total vesting schedule duration after which all tokens are vested (in seconds) |
| _periodDuration | uint32 | duration of a period after which new tokens unlock (in seconds) |
| _lockDuration | uint32 | duration during which tokens are locked (in seconds) |
| _revocable | bool | whether the vesting schedule is revocable or not |
| _amount | uint256 | amount of token attributed by the vesting schedule |
| _beneficiary | address | address of the beneficiary of the tokens |
| _delegatee | address | address to delegate escrow voting power to |
| _ignoreGlobalUnlockSchedule | bool | whether the vesting schedule should ignore the global lock |

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
| _0 | bool | True on success |

### getVestingSchedule

```solidity
function getVestingSchedule(uint256 _index) external view returns (struct VestingSchedulesV2.VestingSchedule)
```

Get vesting schedule

*The vesting schedule structure represents a static configuration used to compute the desiredvesting details of a beneficiary at all times. The values won&#39;t change even after tokens are released.The only dynamic field of the structure is end, and is updated whenever a vesting schedule is revoked*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | Index of the vesting schedule |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | VestingSchedulesV2.VestingSchedule | undefined |

### getVestingScheduleCount

```solidity
function getVestingScheduleCount() external view returns (uint256)
```

Get count of vesting schedules




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | count of vesting schedules |

### isGlobalUnlockedScheduleIgnored

```solidity
function isGlobalUnlockedScheduleIgnored(uint256 _index) external view returns (bool)
```

Get vesting global unlock schedule activation status for a vesting schedule



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | Index of the vesting schedule |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | true if the vesting schedule should ignore the global unlock schedule |

### releaseVestingSchedule

```solidity
function releaseVestingSchedule(uint256 _index) external nonpayable returns (uint256)
```

Release vesting scheduleWhen tokens are released from the escrow, the delegated address of the escrow will see its voting power decrease.The beneficiary has to make sure its delegation parameters are set properly to be able to use/delegate the voting power of its balance.



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
event DelegatedVestingEscrow(uint256 index, address indexed oldDelegatee, address indexed newDelegatee, address indexed beneficiary)
```

Vesting escrow has been delegated



#### Parameters

| Name | Type | Description |
|---|---|---|
| index  | uint256 | Vesting schedule index |
| oldDelegatee `indexed` | address | old delegatee |
| newDelegatee `indexed` | address | new delegatee |
| beneficiary `indexed` | address | vesting schedule beneficiary |

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
event RevokedVestingSchedule(uint256 index, uint256 returnedAmount, uint256 newEnd)
```

Vesting schedule has been revoked



#### Parameters

| Name | Type | Description |
|---|---|---|
| index  | uint256 | Vesting schedule index |
| returnedAmount  | uint256 | Amount of tokens returned to the creator |
| newEnd  | uint256 | New end timestamp after revoke action |



## Errors

### GlobalUnlockUnderlfow

```solidity
error GlobalUnlockUnderlfow()
```

Underflow in global unlock logic (should never happen)




### InvalidRevokedVestingScheduleEnd

```solidity
error InvalidRevokedVestingScheduleEnd()
```

Attempt to revoke a vesting schedule with an invalid end parameter




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





