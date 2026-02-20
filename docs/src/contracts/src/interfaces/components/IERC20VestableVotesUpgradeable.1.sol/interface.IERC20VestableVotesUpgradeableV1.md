# IERC20VestableVotesUpgradeableV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/components/IERC20VestableVotesUpgradeable.1.sol)

**Title:**
ERC20 Vestable Votes Upgradeable Interface(v1)

**Author:**
Alluvial Finance Inc.

This interface exposes methods to manage vestings


## Functions
### getVestingSchedule

Get vesting schedule

The vesting schedule structure represents a static configuration used to compute the desired

vesting details of a beneficiary at all times. The values won't change even after tokens are released.

The only dynamic field of the structure is end, and is updated whenever a vesting schedule is revoked


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

There may delay between the time a user should start vesting tokens and the time the vesting schedule is actually created on the contract.

Typically a user joins the Liquid Collective but some weeks pass before the user gets all legal agreements in place and signed for the

token grant emission to happen. In this case, the vesting schedule created for the token grant would start on the join date which is in the past.

As vesting schedules can be created in the past, this means that you should be careful when creating a vesting schedule and what duration parameters

you use as this contract would allow creating a vesting schedule in the past and even a vesting schedule that has already ended.


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
function revokeVestingSchedule(uint256 _index, uint64 _end) external returns (uint256 returnedAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|Index of the vesting schedule to revoke|
|`_end`|`uint64`|End date for the schedule|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`returnedAmount`|`uint256`|amount returned to the vesting schedule creator|


### releaseVestingSchedule

Release vesting schedule

When tokens are released from the escrow, the delegated address of the escrow will see its voting power decrease.

The beneficiary has to make sure its delegation parameters are set properly to be able to use/delegate the voting power of its balance.


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


## Events
### CreatedVestingSchedule
A new vesting schedule has been created


```solidity
event CreatedVestingSchedule(uint256 index, address indexed creator, address indexed beneficiary, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|Vesting schedule index|
|`creator`|`address`|Creator of the vesting schedule|
|`beneficiary`|`address`|Vesting beneficiary address|
|`amount`|`uint256`|Vesting schedule amount|

### ReleasedVestingSchedule
Vesting schedule has been released


```solidity
event ReleasedVestingSchedule(uint256 index, uint256 releasedAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|Vesting schedule index|
|`releasedAmount`|`uint256`|Amount of tokens released to the beneficiary|

### RevokedVestingSchedule
Vesting schedule has been revoked


```solidity
event RevokedVestingSchedule(uint256 index, uint256 returnedAmount, uint256 newEnd);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|Vesting schedule index|
|`returnedAmount`|`uint256`|Amount of tokens returned to the creator|
|`newEnd`|`uint256`|New end timestamp after revoke action|

### DelegatedVestingEscrow
Vesting escrow has been delegated


```solidity
event DelegatedVestingEscrow(
    uint256 index, address indexed oldDelegatee, address indexed newDelegatee, address indexed beneficiary
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|Vesting schedule index|
|`oldDelegatee`|`address`|old delegatee|
|`newDelegatee`|`address`|new delegatee|
|`beneficiary`|`address`|vesting schedule beneficiary|

## Errors
### UnsufficientVestingScheduleCreatorBalance
Vesting schedule creator has unsufficient balance to create vesting schedule


```solidity
error UnsufficientVestingScheduleCreatorBalance();
```

### InvalidVestingScheduleParameter
Invalid parameter for a vesting schedule


```solidity
error InvalidVestingScheduleParameter(string msg);
```

### VestingScheduleNotRevocableInPast
Attempt to revoke a schedule in the past


```solidity
error VestingScheduleNotRevocableInPast();
```

### VestingScheduleNotRevocable
The vesting schedule is not revocable


```solidity
error VestingScheduleNotRevocable();
```

### VestingScheduleIsLocked
The vesting schedule is locked


```solidity
error VestingScheduleIsLocked();
```

### InvalidRevokedVestingScheduleEnd
Attempt to revoke a vesting schedule with an invalid end parameter


```solidity
error InvalidRevokedVestingScheduleEnd();
```

### ZeroReleasableAmount
No token to release


```solidity
error ZeroReleasableAmount();
```

### GlobalUnlockUnderlfow
Underflow in global unlock logic (should never happen)


```solidity
error GlobalUnlockUnderlfow();
```

