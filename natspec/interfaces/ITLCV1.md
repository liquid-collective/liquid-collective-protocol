# ITLCV1

*Alluvial Finance Inc.*

> TLC Interface (v1)

TLC token interface



## Methods

### allowance

```solidity
function allowance(address owner, address spender) external view returns (uint256)
```



*Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through {transferFrom}. This is zero by default. This value changes when {approve} or {transferFrom} are called.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| spender | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### approve

```solidity
function approve(address spender, uint256 amount) external nonpayable returns (bool)
```



*Sets `amount` as the allowance of `spender` over the caller&#39;s tokens. Returns a boolean value indicating whether the operation succeeded. IMPORTANT: Beware that changing an allowance with this method brings the risk that someone may use both the old and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this race condition is to first reduce the spender&#39;s allowance to 0 and set the desired value afterwards: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729 Emits an {Approval} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```



*Returns the amount of tokens owned by `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### delegate

```solidity
function delegate(address delegatee) external nonpayable
```



*Delegates votes from the sender to `delegatee`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| delegatee | address | undefined |

### delegateBySig

```solidity
function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external nonpayable
```



*Delegates votes from signer to `delegatee`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| delegatee | address | undefined |
| nonce | uint256 | undefined |
| expiry | uint256 | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

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

### delegates

```solidity
function delegates(address account) external view returns (address)
```



*Returns the delegate that `account` has chosen.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getPastTotalSupply

```solidity
function getPastTotalSupply(uint256 timepoint) external view returns (uint256)
```



*Returns the total supply of votes available at a specific moment in the past. If the `clock()` is configured to use block numbers, this will return the value at the end of the corresponding block. NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes. Votes that have not been delegated are still part of total supply, even though they would not participate in a vote.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| timepoint | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getPastVotes

```solidity
function getPastVotes(address account, uint256 timepoint) external view returns (uint256)
```



*Returns the amount of votes that `account` had at a specific moment in the past. If the `clock()` is configured to use block numbers, this will return the value at the end of the corresponding block.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |
| timepoint | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### getVotes

```solidity
function getVotes(address account) external view returns (uint256)
```



*Returns the current amount of votes that `account` has.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### initTLCV1

```solidity
function initTLCV1(address _account) external nonpayable
```

Initializes the TLC Token



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | The initial account to grant all the minted tokens |

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

### migrateVestingSchedules

```solidity
function migrateVestingSchedules() external nonpayable
```

Migrates the vesting schedule state structures




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

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```



*Returns the amount of tokens in existence.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfer

```solidity
function transfer(address to, uint256 amount) external nonpayable returns (bool)
```



*Moves `amount` tokens from the caller&#39;s account to `to`. Returns a boolean value indicating whether the operation succeeded. Emits a {Transfer} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) external nonpayable returns (bool)
```



*Moves `amount` tokens from `from` to `to` using the allowance mechanism. `amount` is then deducted from the caller&#39;s allowance. Returns a boolean value indicating whether the operation succeeded. Emits a {Transfer} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

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

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```



*Emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}. `value` is the new allowance.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| value  | uint256 | undefined |

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

### DelegateChanged

```solidity
event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate)
```



*Emitted when an account changes their delegate.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| delegator `indexed` | address | undefined |
| fromDelegate `indexed` | address | undefined |
| toDelegate `indexed` | address | undefined |

### DelegateVotesChanged

```solidity
event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance)
```



*Emitted when a token transfer or delegate change results in changes to a delegate&#39;s number of votes.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| delegate `indexed` | address | undefined |
| previousBalance  | uint256 | undefined |
| newBalance  | uint256 | undefined |

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

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```



*Emitted when `value` tokens are moved from one account (`from`) to another (`to`). Note that `value` may be zero.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| value  | uint256 | undefined |



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





