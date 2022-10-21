# TLCV1









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
| _0 | uint256 | amount of release tokens |

### createVestingSchedule

```solidity
function createVestingSchedule(uint64 _start, uint32 _lockDuration, uint32 _duration, uint32 _period, bool _revocable, uint256 _amount, address _beneficiary, address _delegatee) external nonpayable returns (uint256)
```

Creates a new vesting schedule



#### Parameters

| Name | Type | Description |
|---|---|---|
| _start | uint64 | start time of the vesting |
| _lockDuration | uint32 | duration during which tokens are locked (in seconds) |
| _duration | uint32 | total vesting schedule duration after which all tokens are vested (in seconds) |
| _period | uint32 | duration of a period after which new tokens unlock (in seconds) |
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
| _0 | bool | undefined |

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

### initTLCV1

```solidity
function initTLCV1(address _account) external nonpayable
```

Initializes the TLC Token



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | The initial account to grant all the minted tokens |

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
event DelegatedVestingEscrow(uint256 index, address oldDelegatee, address newDelegatee)
```

Vesting escrow has been delegated



#### Parameters

| Name | Type | Description |
|---|---|---|
| index  | uint256 | undefined |
| oldDelegatee  | address | undefined |
| newDelegatee  | address | undefined |

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
event RevokedVestingSchedule(uint256 index, uint256 returnedAmount)
```

Vesting schedule has been revoked



#### Parameters

| Name | Type | Description |
|---|---|---|
| index  | uint256 | undefined |
| returnedAmount  | uint256 | undefined |

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

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero




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





