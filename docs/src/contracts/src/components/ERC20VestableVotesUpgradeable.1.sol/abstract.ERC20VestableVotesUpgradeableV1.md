# ERC20VestableVotesUpgradeableV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/components/ERC20VestableVotesUpgradeable.1.sol)

**Inherits:**
[Initializable](/contracts/src/Initializable.sol/contract.Initializable.md), ERC20VotesUpgradeable, [IERC20VestableVotesUpgradeableV1](/contracts/src/interfaces/components/IERC20VestableVotesUpgradeable.1.sol/interface.IERC20VestableVotesUpgradeableV1.md)

**Title:**
ERC20VestableVotesUpgradeableV1

**Author:**
Alluvial Finance Inc.

This is an ERC20 extension that

- can be used as source of vote power (inherited from OpenZeppelin ERC20VotesUpgradeable)

- can delegate vote power from an account to another account (inherited from OpenZeppelin ERC20VotesUpgradeable)

- can manage token vestings: ownership is progressively transferred to a beneficiary according to a vesting schedule

- keeps a history (checkpoints) of each account's vote power



Notes from OpenZeppelin [ERC20VotesUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol)

- vote power can be delegated either by calling the {delegate} function, or by providing a signature to be used with {delegateBySig}

- keeps a history (checkpoints) of each account's vote power

- power can be queried through the public accessors {getVotes} and {getPastVotes}.

- by default, token balance does not account for voting power. This makes transfers cheaper. The downside is that it

requires users to delegate to themselves in order to activate checkpoints and have their voting power tracked.



Notes about token vesting

- any token holder can call the method [createVestingSchedule](/contracts/src/components/ERC20VestableVotesUpgradeable.1.sol/abstract.ERC20VestableVotesUpgradeableV1.md#createvestingschedule) in order to transfer tokens to a beneficiary according to a vesting schedule. When

creating a vesting schedule, tokens are transferred to an escrow that holds the token while the vesting progresses. Voting power of the escrowed token is delegated to the

beneficiary or a delegatee account set by the vesting schedule creator

- the schedule beneficiary call [releaseVestingSchedule](/contracts/src/components/ERC20VestableVotesUpgradeable.1.sol/abstract.ERC20VestableVotesUpgradeableV1.md#releasevestingschedule) to get vested tokens transferred from escrow

- the schedule creator can revoke a revocable schedule by calling [revokeVestingSchedule](/contracts/src/components/ERC20VestableVotesUpgradeable.1.sol/abstract.ERC20VestableVotesUpgradeableV1.md#revokevestingschedule) in which case the non-vested tokens are transfered from the escrow back to the creator

- the schedule beneficiary can delegate escrow voting power to any account by calling [delegateVestingEscrow](/contracts/src/components/ERC20VestableVotesUpgradeable.1.sol/abstract.ERC20VestableVotesUpgradeableV1.md#delegatevestingescrow)



Vesting schedule attributes are

- start : start time of the vesting period

- cliff duration: duration before which first tokens gets ownable

- total duration: duration of the entire vesting (sum of all vesting period durations)

- period duration: duration of a single period of vesting

- lock duration: duration before tokens gets unlocked. can exceed the duration of the vesting chedule

- amount: amount of tokens granted by the vesting schedule

- beneficiary: beneficiary of tokens after they are releaseVestingScheduled

- revocable: whether the schedule can be revoked

- ignoreGlobalUnlockSchedule: whether the schedule should ignore the global unlock schedule



Vesting schedule

- if currentTime < cliff: vestedToken = 0

- if cliff <= currentTime < end: vestedToken = (vestedPeriodCount(currentTime) * periodDuration * amount) / totalDuration

- if end < currentTime: vestedToken = amount



Global unlock schedule

- the global unlock schedule releases 1/24th of the total scheduled amount every month after the local lock end

- the local lock end is the end of the lock period of the vesting schedule

- the global unlock schedule is ignored if the vesting schedule has the ignoreGlobalUnlockSchedule flag set to true

- the global unlock schedule is only a cap on the vested funds that can be withdrawn, it does not alter the vesting



Remark: After cliff new tokens get vested at the end of each period



Vested token & lock period

- a vested token is a token that will be eventually releasable from the escrow to the beneficiary once the lock period is over

- lock period prevents beneficiary from releasing vested tokens before the lock period ends. Vested tokens

will eventually be releasable once the lock period is over



Example: Joe gets a vesting starting on Jan 1st 2022 with duration of 1 year and a lock period of 2 years.

On Jan 1st 2023, Joe will have all tokens vested but can not yet release it due to the lock period.

On Jan 1st 2024, lock period is over and Joe can release all tokens.


## State Variables
### ESCROW

```solidity
bytes32 internal constant ESCROW = bytes32(uint256(keccak256("escrow")) - 1)
```


## Functions
### __ERC20VestableVotes_init


```solidity
function __ERC20VestableVotes_init() internal onlyInitializing;
```

### __ERC20VestableVotes_init_unchained


```solidity
function __ERC20VestableVotes_init_unchained() internal onlyInitializing;
```

### migrateVestingSchedulesFromV1ToV2

This method migrates the state of the vesting schedules from V1 to V2

This method should be used if deployment with the old version using V1 state models is upgraded


```solidity
function migrateVestingSchedulesFromV1ToV2() internal;
```

### getVestingSchedule

Get vesting schedule

The vesting schedule structure represents a static configuration used to compute the desired


```solidity
function getVestingSchedule(uint256 _index) external view returns (VestingSchedulesV2.VestingSchedule memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|Index of the vesting schedule|


### isGlobalUnlockedScheduleIgnored

Get vesting global unlock schedule activation status for a vesting schedule


```solidity
function isGlobalUnlockedScheduleIgnored(uint256 _index) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|Index of the vesting schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the vesting schedule should ignore the global unlock schedule|


### getVestingScheduleCount

Get count of vesting schedules


```solidity
function getVestingScheduleCount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|count of vesting schedules|


### vestingEscrow

Get the address of the escrow for a vesting schedule


```solidity
function vestingEscrow(uint256 _index) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|Index of the vesting schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address of the escrow|


### computeVestingReleasableAmount

Computes the releasable amount of tokens for a vesting schedule.


```solidity
function computeVestingReleasableAmount(uint256 _index) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|index of the vesting schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of releasable tokens|


### computeVestingVestedAmount

Computes the vested amount of tokens for a vesting schedule.


```solidity
function computeVestingVestedAmount(uint256 _index) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|index of the vesting schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of vested tokens|


### createVestingSchedule

Creates a new vesting schedule

As vesting schedules can be created in the past, this means that you should be careful when creating a vesting schedule and what duration parameters


```solidity
function createVestingSchedule(
    uint64 _start,
    uint32 _cliffDuration,
    uint32 _duration,
    uint32 _periodDuration,
    uint32 _lockDuration,
    bool _revocable,
    uint256 _amount,
    address _beneficiary,
    address _delegatee,
    bool _ignoreGlobalUnlockSchedule
) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_start`|`uint64`|start time of the vesting|
|`_cliffDuration`|`uint32`|duration to vesting cliff (in seconds)|
|`_duration`|`uint32`|total vesting schedule duration after which all tokens are vested (in seconds)|
|`_periodDuration`|`uint32`|duration of a period after which new tokens unlock (in seconds)|
|`_lockDuration`|`uint32`|duration during which tokens are locked (in seconds)|
|`_revocable`|`bool`|whether the vesting schedule is revocable or not|
|`_amount`|`uint256`|amount of token attributed by the vesting schedule|
|`_beneficiary`|`address`|address of the beneficiary of the tokens|
|`_delegatee`|`address`|address to delegate escrow voting power to|
|`_ignoreGlobalUnlockSchedule`|`bool`|whether the vesting schedule should ignore the global lock|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|index of the created vesting schedule|


### revokeVestingSchedule

Revoke vesting schedule


```solidity
function revokeVestingSchedule(uint256 _index, uint64 _end) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|Index of the vesting schedule to revoke|
|`_end`|`uint64`|End date for the schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|returnedAmount amount returned to the vesting schedule creator|


### releaseVestingSchedule

Release vesting schedule


```solidity
function releaseVestingSchedule(uint256 _index) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|Index of the vesting schedule to release|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|released amount|


### delegateVestingEscrow

Delegate vesting escrowed tokens


```solidity
function delegateVestingEscrow(uint256 _index, address _delegatee) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|index of the vesting schedule|
|`_delegatee`|`address`|address to delegate the token to|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True on success|


### _createVestingSchedule

Creates a new vesting schedule


```solidity
function _createVestingSchedule(
    address _creator,
    address _beneficiary,
    address _delegatee,
    uint64 _start,
    uint32 _cliffDuration,
    uint32 _duration,
    uint32 _periodDuration,
    uint32 _lockDuration,
    bool _revocable,
    uint256 _amount,
    bool _ignoreGlobalUnlockSchedule
) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_creator`|`address`|creator of the token vesting|
|`_beneficiary`|`address`|beneficiary of tokens after they are releaseVestingScheduled|
|`_delegatee`|`address`|address of the delegate escrowed tokens votes to (if address(0) then it defaults to the beneficiary)|
|`_start`|`uint64`|start time of the vesting period|
|`_cliffDuration`|`uint32`|duration before which first tokens gets ownable|
|`_duration`|`uint32`|duration of the entire vesting (sum of all vesting period durations)|
|`_periodDuration`|`uint32`|duration of a single period of vesting|
|`_lockDuration`|`uint32`|duration before tokens gets unlocked. can exceed the duration of the vesting chedule|
|`_revocable`|`bool`|whether the schedule can be revoked|
|`_amount`|`uint256`|amount of tokens granted by the vesting schedule|
|`_ignoreGlobalUnlockSchedule`|`bool`|whether the schedule should ignore the global unlock schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|index of the created vesting schedule|


### _revokeVestingSchedule

Revoke vesting schedule


```solidity
function _revokeVestingSchedule(uint256 _index, uint64 _end) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|Index of the vesting schedule to revoke|
|`_end`|`uint64`|End date for the schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|returnedAmount amount returned to the vesting schedule creator|


### _releaseVestingSchedule

Release vesting schedule


```solidity
function _releaseVestingSchedule(uint256 _index) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|Index of the vesting schedule to release|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|released amount|


### _delegateVestingEscrow

Delegate vesting escrowed tokens


```solidity
function _delegateVestingEscrow(uint256 _index, address _delegatee) internal returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|index of the vesting schedule|
|`_delegatee`|`address`|address to delegate the token to|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True on success|


### _deterministicVestingEscrow

Internal utility to compute the unique escrow deterministic address


```solidity
function _deterministicVestingEscrow(uint256 _index) internal view returns (address escrow);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|index of the vesting schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`escrow`|`address`|The deterministic escrow address for the vesting schedule index|


### _computeVestingReleasableAmount

Computes the releasable amount of tokens for a vesting schedule.


```solidity
function _computeVestingReleasableAmount(
    VestingSchedulesV2.VestingSchedule memory _vestingSchedule,
    bool _revertIfLocked,
    uint256 _index
) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vestingSchedule`|`VestingSchedulesV2.VestingSchedule`|vesting schedule to compute releasable tokens for|
|`_revertIfLocked`|`bool`|if true will revert if the schedule is locked|
|`_index`|`uint256`|index of the vesting schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of release tokens|


### _computeVestedAmount

Computes the vested amount of tokens for a vesting schedule.


```solidity
function _computeVestedAmount(VestingSchedulesV2.VestingSchedule memory _vestingSchedule, uint256 _time)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vestingSchedule`|`VestingSchedulesV2.VestingSchedule`|vesting schedule to compute vested tokens for|
|`_time`|`uint256`|time to compute the vested amount at|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of release tokens|


### _computeGlobalUnlocked

Computes the unlocked amount of tokens for a vesting schedule according to the global unlock schedule


```solidity
function _computeGlobalUnlocked(uint256 scheduledAmount, uint256 timeSinceLocalLockEnd)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`scheduledAmount`|`uint256`|amount of tokens scheduled for the vesting schedule|
|`timeSinceLocalLockEnd`|`uint256`|time since the local lock end|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount of unlocked tokens|


### _getCurrentTime

Returns current time


```solidity
function _getCurrentTime() internal view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current time|


