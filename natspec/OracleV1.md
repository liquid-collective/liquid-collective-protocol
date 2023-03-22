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

*Only callable by the adminstratorModifying the quorum clears all the reporting data*

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

### getLastReportedEpochId

```solidity
function getLastReportedEpochId() external view returns (uint256)
```

Retrieve the last reported epoch id

*The Oracle contracts expects reports on an epoch id &gt;= that the returned value*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The last reported epoch id |

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

### getReportVariantDetails

```solidity
function getReportVariantDetails(uint256 _idx) external view returns (struct ReportVariants.ReportVariantDetails)
```

Retrieve the details of a report variant



#### Parameters

| Name | Type | Description |
|---|---|---|
| _idx | uint256 | The index of the report variant |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | ReportVariants.ReportVariantDetails | The report variant details |

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
function initOracleV1(address _riverAddress, address _administratorAddress, uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime, uint256 _annualAprUpperBound, uint256 _relativeLowerBound) external nonpayable
```

Initializes the oracle



#### Parameters

| Name | Type | Description |
|---|---|---|
| _riverAddress | address | undefined |
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

### isValidEpoch

```solidity
function isValidEpoch(uint256 epoch) external view returns (bool)
```

Verifies if an epoch is valid or not



#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch | uint256 | The epoch to verify |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if valid |

### proposeAdmin

```solidity
function proposeAdmin(address _newAdmin) external nonpayable
```

Proposes a new address as admin

*This security prevents setting an invalid address as an admin. The pendingadmin has to claim its ownership of the contract, and prove that the newaddress is able to perform regular transactions.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | New admin address |

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
function reportConsensusLayerData(IOracleManagerV1.ConsensusLayerReport report) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| report | IOracleManagerV1.ConsensusLayerReport | undefined |

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

### ClearedReporting

```solidity
event ClearedReporting()
```

Cleared reporting data




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

### RemoveMember

```solidity
event RemoveMember(address indexed member)
```

A member has been removed from the oracle member list



#### Parameters

| Name | Type | Description |
|---|---|---|
| member `indexed` | address | undefined |

### ReportedConsensusLayerData

```solidity
event ReportedConsensusLayerData(address indexed member, bytes32 indexed variant, IOracleManagerV1.ConsensusLayerReport report, uint256 voteCount, uint256 quorum)
```

An oracle member performed a report



#### Parameters

| Name | Type | Description |
|---|---|---|
| member `indexed` | address | undefined |
| variant `indexed` | bytes32 | undefined |
| report  | IOracleManagerV1.ConsensusLayerReport | undefined |
| voteCount  | uint256 | undefined |
| quorum  | uint256 | undefined |

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

### SetLastReportedEpoch

```solidity
event SetLastReportedEpoch(uint256 lastReportedEpoch)
```

The last reported epoch has changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| lastReportedEpoch  | uint256 | undefined |

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

### SetRiver

```solidity
event SetRiver(address _river)
```

The storage river address value has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| _river  | address | undefined |

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




### InvalidEpoch

```solidity
error InvalidEpoch(uint256 epoch)
```

Thrown when the reported epoch is invalid



#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch | uint256 | The invalid epoch |

### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```

An error occured during the initialization



#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | The version that was attempting to be initialized |
| expectedVersion | uint256 | The version that was expected |

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero




### ReportIndexOutOfBounds

```solidity
error ReportIndexOutOfBounds(uint256 index, uint256 length)
```

Thrown when the report indexs fetched is out of bounds



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | Requested index |
| length | uint256 | Size of the variant array |

### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Address performing the call |


