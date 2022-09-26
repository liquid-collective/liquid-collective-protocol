# OracleV1

*Kiln*

> Oracle (v1)

This contract handles the input from the allowed oracle members. Highly inspired by Lido&#39;s implementation.



## Methods

### acceptAdmin

```solidity
function acceptAdmin() external nonpayable
```

Accept the transfer of ownership

*Only callable by the pending admin. Resets the pending admin if succesful.*


### addMember

```solidity
function addMember(address _newOracleMember, uint256 _newQuorum) external nonpayable
```

Adds new address as oracle member, giving the ability to push cl reports.

*Only callable by the adminstrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newOracleMember | address | Address of the new member |
| _newQuorum | uint256 | New quorum value |

### getAdmin

```solidity
function getAdmin() external view returns (address)
```

Retrieves the current admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The admin address |

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

### getPendingAdmin

```solidity
function getPendingAdmin() external view returns (address)
```

Retrieve the current pending admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The pending admin address |

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

### proposeAdmin

```solidity
function proposeAdmin(address _newAdmin) external nonpayable
```

Proposes a new address as admin

*This security prevents setting and invalid address as an admin. The pendingadmin has to claim its ownership of the contract, and proves that the newaddress is able to perform regular transactions.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | New admin address |

### removeMember

```solidity
function removeMember(address _oracleMember, uint256 _newQuorum) external nonpayable
```

Removes an address from the oracle members.

*Only callable by the adminstrator*

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

*Only callable by an oracle memberThe epoch id is expected to be &gt;= to the expected epoch id stored in the contractThe epoch id is expected to be the first epoch of its frame*

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

*Only callable by the adminitratorCannot use an address already in use*

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

*Only callable by the adminstrator*

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
| member `indexed` | address | undefined |

### CLReported

```solidity
event CLReported(uint256 epochId, uint128 newCLBalance, uint32 newCLValidatorCount, address oracleMember)
```

Consensys Layer data has been reported by an oracle member



#### Parameters

| Name | Type | Description |
|---|---|---|
| epochId  | uint256 | undefined |
| newCLBalance  | uint128 | undefined |
| newCLValidatorCount  | uint32 | undefined |
| oracleMember  | address | undefined |

### ExpectedEpochIdUpdated

```solidity
event ExpectedEpochIdUpdated(uint256 epochId)
```

The expected epoch id has been changedS



#### Parameters

| Name | Type | Description |
|---|---|---|
| epochId  | uint256 | undefined |

### Initialize

```solidity
event Initialize(uint256 version, bytes cdata)
```

Emitted when the contract is properly initialized



#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint256 | undefined |
| cdata  | bytes | undefined |

### PostTotalShares

```solidity
event PostTotalShares(uint256 postTotalEth, uint256 prevTotalEth, uint256 timeElapsed, uint256 totalShares)
```

The report has been submitted to river



#### Parameters

| Name | Type | Description |
|---|---|---|
| postTotalEth  | uint256 | undefined |
| prevTotalEth  | uint256 | undefined |
| timeElapsed  | uint256 | undefined |
| totalShares  | uint256 | undefined |

### RemoveMember

```solidity
event RemoveMember(address indexed member)
```

A member has been removed from the oracle member list



#### Parameters

| Name | Type | Description |
|---|---|---|
| member `indexed` | address | undefined |

### SetAdmin

```solidity
event SetAdmin(address indexed admin)
```

The admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| admin `indexed` | address | undefined |

### SetBounds

```solidity
event SetBounds(uint256 annualAprUpperBound, uint256 relativeLowerBound)
```

The report bounds have been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| annualAprUpperBound  | uint256 | undefined |
| relativeLowerBound  | uint256 | undefined |

### SetMember

```solidity
event SetMember(address indexed oldAddress, address indexed newAddress)
```

A member address has been edited



#### Parameters

| Name | Type | Description |
|---|---|---|
| oldAddress `indexed` | address | undefined |
| newAddress `indexed` | address | undefined |

### SetPendingAdmin

```solidity
event SetPendingAdmin(address indexed pendingAdmin)
```

The pending admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| pendingAdmin `indexed` | address | undefined |

### SetQuorum

```solidity
event SetQuorum(uint256 newQuorum)
```

The storage quorum value has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| newQuorum  | uint256 | undefined |

### SetSpec

```solidity
event SetSpec(uint64 epochsPerFrame, uint64 slotsPerEpoch, uint64 secondsPerSlot, uint64 genesisTime)
```

The consensus layer spec has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| epochsPerFrame  | uint64 | undefined |
| slotsPerEpoch  | uint64 | undefined |
| secondsPerSlot  | uint64 | undefined |
| genesisTime  | uint64 | undefined |



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

### InvalidArgument

```solidity
error InvalidArgument()
```

The argument was invalid




### InvalidCall

```solidity
error InvalidCall()
```

The call was invalid




### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```

An error occured during the initialization



#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | The version that was attempting the be initialized |
| expectedVersion | uint256 | The version that was expected |

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero




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

The delta in balance is under the allowed lower bound



#### Parameters

| Name | Type | Description |
|---|---|---|
| prevTotalEth | uint256 | The previous total balance |
| postTotalEth | uint256 | The new total balance |
| timeElapsed | uint256 | The time ssince last report |
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
| timeElapsed | uint256 | The time ssince last report |
| annualAprUpperBound | uint256 | The maximum apr allowed |

### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Addres performing the call |


