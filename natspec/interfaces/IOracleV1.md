# IOracleV1

*Kiln*

> Oracle Interface (v1)

This interface exposes methods to handle the input from the allowed oracle members.Highly inspired by Lido&#39;s implementation.



## Methods

### addMember

```solidity
function addMember(address _newOracleMember, uint256 _newQuorum) external nonpayable
```

Adds new address as oracle member, giving the ability to push cl reports.

*Only callable by the adminstratorModifying the quorum clears all the reporting data*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newOracleMember | address | Address of the new member |
| _newQuorum | uint256 | New quorum value |

### getCLSpec

```solidity
function getCLSpec() external view returns (struct CLSpec.CLSpecStruct)
```

Retrieve the current cl spec




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | CLSpec.CLSpecStruct | The Consensus Layer Specification |

### getCurrentEpochId

```solidity
function getCurrentEpochId() external view returns (uint256)
```

Retrieve the current epoch id based on block timestamp




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current epoch id |

### getCurrentFrame

```solidity
function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime)
```

Retrieve the current frame details




#### Returns

| Name | Type | Description |
|---|---|---|
| _startEpochId | uint256 | The epoch at the beginning of the frame |
| _startTime | uint256 | The timestamp of the beginning of the frame in seconds |
| _endTime | uint256 | The timestamp of the end of the frame in seconds |

### getExpectedEpochId

```solidity
function getExpectedEpochId() external view returns (uint256)
```

Retrieve expected epoch id




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current expected epoch id |

### getFrameFirstEpochId

```solidity
function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256)
```

Retrieve the first epoch id of the frame of the provided epoch id



#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId | uint256 | Epoch id used to get the frame |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The first epoch id of the frame containing the given epoch id |

### getGlobalReportStatus

```solidity
function getGlobalReportStatus() external view returns (uint256)
```

Retrieve member report status




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The raw report status value |

### getLastCompletedEpochId

```solidity
function getLastCompletedEpochId() external view returns (uint256)
```

Retrieve the last completed epoch id




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The last completed epoch id |

### getMemberReportStatus

```solidity
function getMemberReportStatus(address _oracleMember) external view returns (bool)
```

Retrieve member report status



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleMember | address | Address of member to check |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if member has reported |

### getOracleMembers

```solidity
function getOracleMembers() external view returns (address[])
```

Retrieve the list of oracle members




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address[] | The oracle members |

### getQuorum

```solidity
function getQuorum() external view returns (uint256)
```

Retrieve the current quorum




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current quorum |

### getReportBounds

```solidity
function getReportBounds() external view returns (struct ReportBounds.ReportBoundsStruct)
```

Retrieve the report bounds




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | ReportBounds.ReportBoundsStruct | The report bounds |

### getReportVariant

```solidity
function getReportVariant(uint256 _idx) external view returns (uint64 _clBalance, uint32 _clValidators, uint16 _reportCount)
```

Retrieve decoded report at provided index



#### Parameters

| Name | Type | Description |
|---|---|---|
| _idx | uint256 | Index of report |

#### Returns

| Name | Type | Description |
|---|---|---|
| _clBalance | uint64 | The reported consensus layer balance sum of River&#39;s validators |
| _clValidators | uint32 | The reported validator count |
| _reportCount | uint16 | The number of similar reports |

### getReportVariantsCount

```solidity
function getReportVariantsCount() external view returns (uint256)
```

Retrieve report variants count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The count of report variants |

### getRiver

```solidity
function getRiver() external view returns (address)
```

Retrieve River address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The address of River |

### getTime

```solidity
function getTime() external view returns (uint256)
```

Retrieve the block timestamp




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current timestamp from the EVM context |

### initOracleV1

```solidity
function initOracleV1(address _river, address _administratorAddress, uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime, uint256 _annualAprUpperBound, uint256 _relativeLowerBound) external nonpayable
```

Initializes the oracle



#### Parameters

| Name | Type | Description |
|---|---|---|
| _river | address | Address of the River contract, able to receive oracle input data after quorum is met |
| _administratorAddress | address | Address able to call administrative methods |
| _epochsPerFrame | uint64 | CL spec parameter. Number of epochs in a frame. |
| _slotsPerEpoch | uint64 | CL spec parameter. Number of slots in one epoch. |
| _secondsPerSlot | uint64 | CL spec parameter. Number of seconds between slots. |
| _genesisTime | uint64 | CL spec parameter. Timestamp of the genesis slot. |
| _annualAprUpperBound | uint256 | CL bound parameter. Maximum apr allowed for balance increase. Delta between updates is extrapolated on a year time frame. |
| _relativeLowerBound | uint256 | CL bound parameter. Maximum relative balance decrease. |

### isMember

```solidity
function isMember(address _memberAddress) external view returns (bool)
```

Returns true if address is member

*Performs a naive search, do not call this on-chain, used as an off-chain helper*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _memberAddress | address | Address of the member |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if address is a member |

### removeMember

```solidity
function removeMember(address _oracleMember, uint256 _newQuorum) external nonpayable
```

Removes an address from the oracle members.

*Only callable by the adminstratorModifying the quorum clears all the reporting dataRemaining members that have already voted should vote again for the same frame.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleMember | address | Address to remove |
| _newQuorum | uint256 | New quorum value |

### reportConsensusLayerData

```solidity
function reportConsensusLayerData(uint256 _epochId, uint64 _clValidatorsBalance, uint32 _clValidatorCount) external nonpayable
```

Report cl chain data

*Only callable by an oracle memberThe epoch id is expected to be &gt;= to the expected epoch id stored in the contractThe epoch id is expected to be the first epoch of its frameThe Consensus Layer Validator count is the amount of running validators managed by River.Until withdrawals are enabled, this count also takes into account any exited and slashed validatoras funds are still locked on the consensus layer.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId | uint256 | Epoch where the balance and validator count has been computed |
| _clValidatorsBalance | uint64 | Total balance of River validators |
| _clValidatorCount | uint32 | Total River validator count |

### setCLSpec

```solidity
function setCLSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime) external nonpayable
```

Edits the cl spec parameters

*Only callable by the adminstrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochsPerFrame | uint64 | Number of epochs in a frame. |
| _slotsPerEpoch | uint64 | Number of slots in one epoch. |
| _secondsPerSlot | uint64 | Number of seconds between slots. |
| _genesisTime | uint64 | Timestamp of the genesis slot. |

### setMember

```solidity
function setMember(address _oracleMember, address _newAddress) external nonpayable
```

Changes the address of an oracle member

*Only callable by the adminitratorCannot use an address already in useThis call will clear all the reporting data*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleMember | address | Address to change |
| _newAddress | address | New address for the member |

### setQuorum

```solidity
function setQuorum(uint256 _newQuorum) external nonpayable
```

Edits the quorum required to forward cl data to River

*Modifying the quorum clears all the reporting data*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newQuorum | uint256 | New quorum parameter |

### setReportBounds

```solidity
function setReportBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound) external nonpayable
```

Edits the cl bounds parameters

*Only callable by the adminstrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _annualAprUpperBound | uint256 | Maximum apr allowed for balance increase. Delta between updates is extrapolated on a year time frame. |
| _relativeLowerBound | uint256 | Maximum relative balance decrease. |



## Events

### AddMember

```solidity
event AddMember(address indexed member)
```

A member has been added to the oracle member list



#### Parameters

| Name | Type | Description |
|---|---|---|
| member `indexed` | address | The address of the member |

### CLReported

```solidity
event CLReported(uint256 epochId, uint128 newCLBalance, uint32 newCLValidatorCount, address oracleMember)
```

Consensus Layer data has been reported by an oracle member



#### Parameters

| Name | Type | Description |
|---|---|---|
| epochId  | uint256 | The epoch of the report |
| newCLBalance  | uint128 | The new consensus layer balance |
| newCLValidatorCount  | uint32 | The new consensus layer validator count |
| oracleMember  | address | The oracle member that reported |

### ExpectedEpochIdUpdated

```solidity
event ExpectedEpochIdUpdated(uint256 epochId)
```

The expected epoch id has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| epochId  | uint256 | The new expected epoch id |

### PostTotalShares

```solidity
event PostTotalShares(uint256 postTotalEth, uint256 prevTotalEth, uint256 timeElapsed, uint256 totalShares)
```

The report has been submitted to river



#### Parameters

| Name | Type | Description |
|---|---|---|
| postTotalEth  | uint256 | The new total ETH balance |
| prevTotalEth  | uint256 | The previous total ETH balance |
| timeElapsed  | uint256 | Time since last report |
| totalShares  | uint256 | The new total amount of shares |

### RemoveMember

```solidity
event RemoveMember(address indexed member)
```

A member has been removed from the oracle member list



#### Parameters

| Name | Type | Description |
|---|---|---|
| member `indexed` | address | The address of the member |

### SetBounds

```solidity
event SetBounds(uint256 annualAprUpperBound, uint256 relativeLowerBound)
```

The report bounds have been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| annualAprUpperBound  | uint256 | The maximum allowed apr. 10% means increases in balance extrapolated to a year should not exceed 10%. |
| relativeLowerBound  | uint256 | The maximum allowed balance decrease as a relative % of the total balance |

### SetMember

```solidity
event SetMember(address indexed oldAddress, address indexed newAddress)
```

A member address has been edited



#### Parameters

| Name | Type | Description |
|---|---|---|
| oldAddress `indexed` | address | The previous member address |
| newAddress `indexed` | address | The new member address |

### SetQuorum

```solidity
event SetQuorum(uint256 newQuorum)
```

The storage quorum value has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| newQuorum  | uint256 | The new quorum value |

### SetRiver

```solidity
event SetRiver(address _river)
```

The storage river address value has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| _river  | address | The new river address |

### SetSpec

```solidity
event SetSpec(uint64 epochsPerFrame, uint64 slotsPerEpoch, uint64 secondsPerSlot, uint64 genesisTime)
```

The consensus layer spec has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| epochsPerFrame  | uint64 | The number of epochs inside a frame (225 = 24 hours) |
| slotsPerEpoch  | uint64 | The number of slots inside an epoch (32 on ethereum mainnet) |
| secondsPerSlot  | uint64 | The time between two slots (12 seconds on ethereum mainnet) |
| genesisTime  | uint64 | The timestamp of block #0 |



## Errors

### AddressAlreadyInUse

```solidity
error AddressAlreadyInUse(address newAddress)
```

The address is already in use by an oracle member



#### Parameters

| Name | Type | Description |
|---|---|---|
| newAddress | address | The address already in use |

### AlreadyReported

```solidity
error AlreadyReported(uint256 epochId, address member)
```

The member already reported on the given epoch id



#### Parameters

| Name | Type | Description |
|---|---|---|
| epochId | uint256 | The epoch id provided as input |
| member | address | The oracle member |

### EpochTooOld

```solidity
error EpochTooOld(uint256 providedEpochId, uint256 minExpectedEpochId)
```

The provided epoch is too old compared to the expected epoch id



#### Parameters

| Name | Type | Description |
|---|---|---|
| providedEpochId | uint256 | The epoch id provided as input |
| minExpectedEpochId | uint256 | The minimum epoch id expected |

### NotFrameFirstEpochId

```solidity
error NotFrameFirstEpochId(uint256 providedEpochId, uint256 expectedFrameFirstEpochId)
```

The provided epoch is not at the beginning of its frame



#### Parameters

| Name | Type | Description |
|---|---|---|
| providedEpochId | uint256 | The epoch id provided as input |
| expectedFrameFirstEpochId | uint256 | The frame first epoch id that was expected |

### TotalValidatorBalanceDecreaseOutOfBound

```solidity
error TotalValidatorBalanceDecreaseOutOfBound(uint256 prevTotalEth, uint256 postTotalEth, uint256 timeElapsed, uint256 relativeLowerBound)
```

The negative delta in balance is above the allowed lower bound



#### Parameters

| Name | Type | Description |
|---|---|---|
| prevTotalEth | uint256 | The previous total balance |
| postTotalEth | uint256 | The new total balance |
| timeElapsed | uint256 | The time since last report |
| relativeLowerBound | uint256 | The maximum relative decrease allowed |

### TotalValidatorBalanceIncreaseOutOfBound

```solidity
error TotalValidatorBalanceIncreaseOutOfBound(uint256 prevTotalEth, uint256 postTotalEth, uint256 timeElapsed, uint256 annualAprUpperBound)
```

The delta in balance is above the allowed upper bound



#### Parameters

| Name | Type | Description |
|---|---|---|
| prevTotalEth | uint256 | The previous total balance |
| postTotalEth | uint256 | The new total balance |
| timeElapsed | uint256 | The time since last report |
| annualAprUpperBound | uint256 | The maximum apr allowed |


