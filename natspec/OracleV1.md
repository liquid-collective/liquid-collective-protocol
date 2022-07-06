# OracleV1

*Kiln*

> Oracle (v1)

This contract handles the input from the allowed oracle members. Highly inspired by Lido&#39;s implementation.



## Methods

### addMember

```solidity
function addMember(address _newOracleMember) external nonpayable
```

Adds new address as oracle member, giving the ability to push beacon reports.

*Only callable by the adminstrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newOracleMember | address | Address of the new member |

### getAdministrator

```solidity
function getAdministrator() external view returns (address)
```

Retrieve system administrator address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getBeaconBounds

```solidity
function getBeaconBounds() external view returns (struct BeaconReportBounds.BeaconReportBoundsStruct)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | BeaconReportBounds.BeaconReportBoundsStruct | undefined |

### getBeaconSpec

```solidity
function getBeaconSpec() external view returns (struct BeaconSpec.BeaconSpecStruct)
```

Retrieve the current beacon spec




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | BeaconSpec.BeaconSpecStruct | undefined |

### getCurrentEpochId

```solidity
function getCurrentEpochId() external view returns (uint256)
```

Retrieve the current epoch id based on block timestamp




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getCurrentFrame

```solidity
function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime)
```

Retrieve the current frame details




#### Returns

| Name | Type | Description |
|---|---|---|
| _startEpochId | uint256 | undefined |
| _startTime | uint256 | undefined |
| _endTime | uint256 | undefined |

### getExpectedEpochId

```solidity
function getExpectedEpochId() external view returns (uint256)
```

Retrieve expected epoch id




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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
| _0 | uint256 | undefined |

### getGlobalReportStatus

```solidity
function getGlobalReportStatus() external view returns (uint256)
```

Retrieve member report status




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getLastCompletedEpochId

```solidity
function getLastCompletedEpochId() external view returns (uint256)
```

Retrieve the last completed epoch id




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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
| _0 | bool | undefined |

### getOracleMembers

```solidity
function getOracleMembers() external view returns (address[])
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address[] | undefined |

### getQuorum

```solidity
function getQuorum() external view returns (uint256)
```

Retrieve the current quorum




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getReportVariant

```solidity
function getReportVariant(uint256 _idx) external view returns (uint64 _beaconBalance, uint32 _beaconValidators, uint16 _reportCount)
```

Retrieve decoded report at provided index



#### Parameters

| Name | Type | Description |
|---|---|---|
| _idx | uint256 | Index of report |

#### Returns

| Name | Type | Description |
|---|---|---|
| _beaconBalance | uint64 | undefined |
| _beaconValidators | uint32 | undefined |
| _reportCount | uint16 | undefined |

### getReportVariantsCount

```solidity
function getReportVariantsCount() external view returns (uint256)
```

Retrieve report variants count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getRiver

```solidity
function getRiver() external view returns (address)
```

Retrieve River address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getTime

```solidity
function getTime() external view returns (uint256)
```

Retrieve the block timestamp




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### initOracleV1

```solidity
function initOracleV1(address _riverContractAddress, address _administratorAddress, uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime, uint256 _annualAprUpperBound, uint256 _relativeLowerBound) external nonpayable
```

Initializes the oracle



#### Parameters

| Name | Type | Description |
|---|---|---|
| _riverContractAddress | address | Address of the River contract, able to receive oracle input data after quorum is met |
| _administratorAddress | address | Address able to call administrative methods |
| _epochsPerFrame | uint64 | Beacon spec parameter. Number of epochs in a frame. |
| _slotsPerEpoch | uint64 | Beacon spec parameter. Number of slots in one epoch. |
| _secondsPerSlot | uint64 | Beacon spec parameter. Number of seconds between slots. |
| _genesisTime | uint64 | Beacon spec parameter. Timestamp of the genesis slot. |
| _annualAprUpperBound | uint256 | Beacon bound parameter. Maximum apr allowed for balance increase. Delta between updates is extrapolated on a year time frame. |
| _relativeLowerBound | uint256 | Beacon bound parameter. Maximum relative balance decrease. |

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
| _0 | bool | undefined |

### removeMember

```solidity
function removeMember(address _oracleMember) external nonpayable
```

Removes an address from the oracle members.

*Only callable by the adminstrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleMember | address | Address to remove |

### reportBeacon

```solidity
function reportBeacon(uint256 _epochId, uint64 _beaconBalance, uint32 _beaconValidators) external nonpayable
```

Report beacon chain data

*Only callable by an oracle member*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId | uint256 | Epoch where the balance and validator count has been computed |
| _beaconBalance | uint64 | Total balance of River validators |
| _beaconValidators | uint32 | Total River validator count |

### setBeaconBounds

```solidity
function setBeaconBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound) external nonpayable
```

Edits the beacon bounds parameters

*Only callable by the adminstrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _annualAprUpperBound | uint256 | Maximum apr allowed for balance increase. Delta between updates is extrapolated on a year time frame. |
| _relativeLowerBound | uint256 | Maximum relative balance decrease. |

### setBeaconSpec

```solidity
function setBeaconSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime) external nonpayable
```

Edits the beacon spec parameters

*Only callable by the adminstrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochsPerFrame | uint64 | Number of epochs in a frame. |
| _slotsPerEpoch | uint64 | Number of slots in one epoch. |
| _secondsPerSlot | uint64 | Number of seconds between slots. |
| _genesisTime | uint64 | Timestamp of the genesis slot. |

### setQuorum

```solidity
function setQuorum(uint256 _newQuorum) external nonpayable
```

Edits the quorum required to forward beacon data to River

*Only callable by the adminstrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newQuorum | uint256 | New quorum parameter |



## Events

### BeaconReported

```solidity
event BeaconReported(uint256 _epochId, uint128 _newBeaconBalance, uint32 _newBeaconValidatorCount, address _oracleMember)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId  | uint256 | undefined |
| _newBeaconBalance  | uint128 | undefined |
| _newBeaconValidatorCount  | uint32 | undefined |
| _oracleMember  | address | undefined |

### ExpectedEpochIdUpdated

```solidity
event ExpectedEpochIdUpdated(uint256 _epochId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId  | uint256 | undefined |

### PostTotalShares

```solidity
event PostTotalShares(uint256 _postTotalEth, uint256 _prevTotalEth, uint256 _timeElapsed, uint256 _totalShares)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _postTotalEth  | uint256 | undefined |
| _prevTotalEth  | uint256 | undefined |
| _timeElapsed  | uint256 | undefined |
| _totalShares  | uint256 | undefined |

### QuorumChanged

```solidity
event QuorumChanged(uint256 _newQuorum)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newQuorum  | uint256 | undefined |



## Errors

### AlreadyReported

```solidity
error AlreadyReported(uint256 _epochId, address _member)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId | uint256 | undefined |
| _member | address | undefined |

### BeaconBalanceDecreaseOutOfBounds

```solidity
error BeaconBalanceDecreaseOutOfBounds(uint256 _prevTotalEth, uint256 _postTotalEth, uint256 _timeElapsed, uint256 _relativeLowerBound)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _prevTotalEth | uint256 | undefined |
| _postTotalEth | uint256 | undefined |
| _timeElapsed | uint256 | undefined |
| _relativeLowerBound | uint256 | undefined |

### BeaconBalanceIncreaseOutOfBounds

```solidity
error BeaconBalanceIncreaseOutOfBounds(uint256 _prevTotalEth, uint256 _postTotalEth, uint256 _timeElapsed, uint256 _annualAprUpperBound)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _prevTotalEth | uint256 | undefined |
| _postTotalEth | uint256 | undefined |
| _timeElapsed | uint256 | undefined |
| _annualAprUpperBound | uint256 | undefined |

### EpochTooOld

```solidity
error EpochTooOld(uint256 _providedEpochId, uint256 _minExpectedEpochId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _providedEpochId | uint256 | undefined |
| _minExpectedEpochId | uint256 | undefined |

### InvalidArgument

```solidity
error InvalidArgument()
```






### InvalidCall

```solidity
error InvalidCall()
```






### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | undefined |
| expectedVersion | uint256 | undefined |

### NotFrameFirstEpochId

```solidity
error NotFrameFirstEpochId(uint256 _providedEpochId, uint256 _expectedFrameFirstEpochId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _providedEpochId | uint256 | undefined |
| _expectedFrameFirstEpochId | uint256 | undefined |

### Unauthorized

```solidity
error Unauthorized(address caller)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | undefined |


