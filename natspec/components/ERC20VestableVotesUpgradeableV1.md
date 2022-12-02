# ERC20VestableVotesUpgradeableV1

*Alluvial*

> ERC20VestableVotesUpgradeableV1

This is an ERC20 extension that- can be used as source of vote power (inherited from OpenZeppelin ERC20VotesUpgradeable)- can delegate vote power from an account to another account (inherited from OpenZeppelin ERC20VotesUpgradeable)- can manage token vestings: ownership is progressively transferred to a beneficiary according to a vesting schedule- keeps a history (checkpoints) of each account&#39;s vote power@notice Notes from OpenZeppelin [ERC20VotesUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol)- vote power can be delegated either by calling the {delegate} function, or by providing a signature to be used with {delegateBySig}- keeps a history (checkpoints) of each account&#39;s vote power- power can be queried through the public accessors {getVotes} and {getPastVotes}.- by default, token balance does not account for voting power. This makes transfers cheaper. The downside is that itrequires users to delegate to themselves in order to activate checkpoints and have their voting power tracked.@notice Notes about token vesting- any token holder can call the method {createVestingSchedule} in order to transfer tokens to a beneficiary according to a vesting schedule. Whencreating a vesting schedule, tokens are transferred to an escrow that holds the token while the vesting progresses. Voting power of the escrowed token is delegated to thebeneficiary or a delegatee account set by the vesting schedule creator- the schedule beneficiary call {releaseVestingSchedule} to get vested tokens transferred from escrow- the schedule creator can revoke a revocable schedule by calling {revokeVestingSchedule} in which case the non-vested tokens are transfered from the escrow back to the creator- the schedule beneficiary can delegate escrow voting power to any account by calling {delegateVestingEscrow}@notice Vesting schedule attributes are- start : start time of the vesting period- cliff duration: duration before which first tokens gets ownable- total duration: duration of the entire vesting (sum of all vesting period durations)- period duration: duration of a single period of vesting- lock duration: duration before tokens gets unlocked. can exceed the duration of the vesting chedule- amount: amount of tokens granted by the vesting schedule- beneficiary: beneficiary of tokens after they are releaseVestingScheduled- revocable: whether the schedule can be revoked@notice Vesting schedule- if currentTime &lt; cliff: vestedToken = 0- if cliff &lt;= currentTime &lt; end: vestedToken = (vestedPeriodCount(currentTime) * periodDuration * amount) / totalDuration- if end &lt; currentTime: vestedToken = amount@notice Remark: After cliff new tokens get vested at the end of each period@notice Vested token &amp; lock period- a vested token is a token that will be eventually releasable from the escrow to the beneficiary once the lock period is over- lock period prevents beneficiary from releasing vested tokens before the lock period ends. Vested tokenswill eventually be releasable once the lock period is over@notice Example: Joe gets a vesting starting on Jan 1st 2022 with duration of 1 year and a lock period of 2 years.On Jan 1st 2023, Joe will have all tokens vested but can not yet release it due to the lock period.On Jan 1st 2024, lock period is over and Joe can release all tokens.



## Methods

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```



*See {IERC20Permit-DOMAIN_SEPARATOR}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### allowance

```solidity
function allowance(address owner, address spender) external view returns (uint256)
```



*See {IERC20-allowance}.*

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



*See {IERC20-approve}. NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on `transferFrom`. This is semantically equivalent to an infinite approval. Requirements: - `spender` cannot be the zero address.*

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



*See {IERC20-balanceOf}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### checkpoints

```solidity
function checkpoints(address account, uint32 pos) external view returns (struct ERC20VotesUpgradeable.Checkpoint)
```



*Get the `pos`-th checkpoint for `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |
| pos | uint32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | ERC20VotesUpgradeable.Checkpoint | undefined |

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
function createVestingSchedule(uint64 _start, uint32 _cliffDuration, uint32 _duration, uint32 _periodDuration, uint32 _lockDuration, bool _revocable, uint256 _amount, address _beneficiary, address _delegatee) external nonpayable returns (uint256)
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

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | index of the created vesting schedule |

### decimals

```solidity
function decimals() external view returns (uint8)
```



*Returns the number of decimals used to get its user representation. For example, if `decimals` equals `2`, a balance of `505` tokens should be displayed to a user as `5.05` (`505 / 10 ** 2`). Tokens usually opt for a value of 18, imitating the relationship between Ether and Wei. This is the value {ERC20} uses, unless this function is overridden; NOTE: This information is only used for _display_ purposes: it in no way affects any of the arithmetic of the contract, including {IERC20-balanceOf} and {IERC20-transfer}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### decreaseAllowance

```solidity
function decreaseAllowance(address spender, uint256 subtractedValue) external nonpayable returns (bool)
```



*Atomically decreases the allowance granted to `spender` by the caller. This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}. Emits an {Approval} event indicating the updated allowance. Requirements: - `spender` cannot be the zero address. - `spender` must have allowance for the caller of at least `subtractedValue`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| subtractedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### delegate

```solidity
function delegate(address delegatee) external nonpayable
```



*Delegate votes from the sender to `delegatee`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| delegatee | address | undefined |

### delegateBySig

```solidity
function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external nonpayable
```



*Delegates votes from signer to `delegatee`*

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



*Get the address `account` is currently delegating to.*

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
function getPastTotalSupply(uint256 blockNumber) external view returns (uint256)
```



*Retrieve the `totalSupply` at the end of `blockNumber`. Note, this value is the sum of all balances. It is but NOT the sum of all the delegated votes! Requirements: - `blockNumber` must have been already mined*

#### Parameters

| Name | Type | Description |
|---|---|---|
| blockNumber | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getPastVotes

```solidity
function getPastVotes(address account, uint256 blockNumber) external view returns (uint256)
```



*Retrieve the number of votes for `account` at the end of `blockNumber`. Requirements: - `blockNumber` must have been already mined*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |
| blockNumber | uint256 | undefined |

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



*Gets the current votes balance for `account`*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### increaseAllowance

```solidity
function increaseAllowance(address spender, uint256 addedValue) external nonpayable returns (bool)
```



*Atomically increases the allowance granted to `spender` by the caller. This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}. Emits an {Approval} event indicating the updated allowance. Requirements: - `spender` cannot be the zero address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| addedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### name

```solidity
function name() external view returns (string)
```



*Returns the name of the token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### nonces

```solidity
function nonces(address owner) external view returns (uint256)
```



*See {IERC20Permit-nonces}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### numCheckpoints

```solidity
function numCheckpoints(address account) external view returns (uint32)
```



*Get number of checkpoints for `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | undefined |

### permit

```solidity
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonpayable
```



*See {IERC20Permit-permit}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| spender | address | undefined |
| value | uint256 | undefined |
| deadline | uint256 | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

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
function revokeVestingSchedule(uint256 _index, uint64 _end) external nonpayable returns (uint256)
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
| _0 | uint256 | amount returned to the vesting schedule creator |

### symbol

```solidity
function symbol() external view returns (string)
```



*Returns the symbol of the token, usually a shorter version of the name.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```



*See {IERC20-totalSupply}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfer

```solidity
function transfer(address to, uint256 amount) external nonpayable returns (bool)
```



*See {IERC20-transfer}. Requirements: - `to` cannot be the zero address. - the caller must have a balance of at least `amount`.*

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



*See {IERC20-transferFrom}. Emits an {Approval} event indicating the updated allowance. This is not required by the EIP. See the note at the beginning of {ERC20}. NOTE: Does not update the allowance if the current allowance is the maximum `uint256`. Requirements: - `from` and `to` cannot be the zero address. - `from` must have a balance of at least `amount`. - the caller must have allowance for ``from``&#39;s tokens of at least `amount`.*

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
| index  | uint256 | undefined |
| creator `indexed` | address | undefined |
| beneficiary `indexed` | address | undefined |
| amount  | uint256 | undefined |

### DelegateChanged

```solidity
event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate)
```





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
| index  | uint256 | undefined |
| oldDelegatee `indexed` | address | undefined |
| newDelegatee `indexed` | address | undefined |
| beneficiary `indexed` | address | undefined |

### Initialized

```solidity
event Initialized(uint8 version)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint8 | undefined |

### ReleasedVestingSchedule

```solidity
event ReleasedVestingSchedule(uint256 index, uint256 releasedAmount)
```

Vesting schedule has been released



#### Parameters

| Name | Type | Description |
|---|---|---|
| index  | uint256 | undefined |
| releasedAmount  | uint256 | undefined |

### RevokedVestingSchedule

```solidity
event RevokedVestingSchedule(uint256 index, uint256 returnedAmount, uint256 newEnd)
```

Vesting schedule has been revoked



#### Parameters

| Name | Type | Description |
|---|---|---|
| index  | uint256 | undefined |
| returnedAmount  | uint256 | undefined |
| newEnd  | uint256 | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| value  | uint256 | undefined |



## Errors

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

### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Address performing the call |

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




### VestingScheduleNotFound

```solidity
error VestingScheduleNotFound(uint256 index)
```

The VestingSchedule was not found



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | vesting schedule index |

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





