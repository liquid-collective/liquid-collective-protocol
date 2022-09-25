# IOracleV1

*Kiln*

> Oracle (v1)

This contract handles the input from the allowed oracle members. Highly inspired by Lido&#39;s implementation.



## Methods

### addMember

```solidity
function addMember(address _newOracleMember, uint256 _newQuorum) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newOracleMember | address | undefined |
| _newQuorum | uint256 | undefined |

### getCLSpec

```solidity
function getCLSpec() external view returns (struct CLSpec.CLSpecStruct)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | CLSpec.CLSpecStruct | undefined |

### getCurrentEpochId

```solidity
function getCurrentEpochId() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getCurrentFrame

```solidity
function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime)
```






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






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getFrameFirstEpochId

```solidity
function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getGlobalReportStatus

```solidity
function getGlobalReportStatus() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getLastCompletedEpochId

```solidity
function getLastCompletedEpochId() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getMemberReportStatus

```solidity
function getMemberReportStatus(address _oracleMember) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleMember | address | undefined |

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






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getReportBounds

```solidity
function getReportBounds() external view returns (struct ReportBounds.ReportBoundsStruct)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | ReportBounds.ReportBoundsStruct | undefined |

### getReportVariant

```solidity
function getReportVariant(uint256 _idx) external view returns (uint64 _clBalance, uint32 _clValidators, uint16 _reportCount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _idx | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _clBalance | uint64 | undefined |
| _clValidators | uint32 | undefined |
| _reportCount | uint16 | undefined |

### getReportVariantsCount

```solidity
function getReportVariantsCount() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getRiver

```solidity
function getRiver() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getTime

```solidity
function getTime() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### initOracleV1

```solidity
function initOracleV1(address _riverContractAddress, address _administratorAddress, uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime, uint256 _annualAprUpperBound, uint256 _relativeLowerBound) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _riverContractAddress | address | undefined |
| _administratorAddress | address | undefined |
| _epochsPerFrame | uint64 | undefined |
| _slotsPerEpoch | uint64 | undefined |
| _secondsPerSlot | uint64 | undefined |
| _genesisTime | uint64 | undefined |
| _annualAprUpperBound | uint256 | undefined |
| _relativeLowerBound | uint256 | undefined |

### isMember

```solidity
function isMember(address _memberAddress) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _memberAddress | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### removeMember

```solidity
function removeMember(address _oracleMember, uint256 _newQuorum) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleMember | address | undefined |
| _newQuorum | uint256 | undefined |

### reportConsensusLayerData

```solidity
function reportConsensusLayerData(uint256 _epochId, uint64 _clBalance, uint32 _clValidators) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId | uint256 | undefined |
| _clBalance | uint64 | undefined |
| _clValidators | uint32 | undefined |

### setCLSpec

```solidity
function setCLSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochsPerFrame | uint64 | undefined |
| _slotsPerEpoch | uint64 | undefined |
| _secondsPerSlot | uint64 | undefined |
| _genesisTime | uint64 | undefined |

### setMember

```solidity
function setMember(address _oracleMember, address _newAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleMember | address | undefined |
| _newAddress | address | undefined |

### setQuorum

```solidity
function setQuorum(uint256 _newQuorum) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newQuorum | uint256 | undefined |

### setReportBounds

```solidity
function setReportBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _annualAprUpperBound | uint256 | undefined |
| _relativeLowerBound | uint256 | undefined |



## Events

### AddMember

```solidity
event AddMember(address indexed member)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| member `indexed` | address | undefined |

### BeaconReported

```solidity
event BeaconReported(uint256 _epochId, uint128 _newBeaconBalance, uint32 _newBeaconValidatorCount, address indexed _oracleMember)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId  | uint256 | undefined |
| _newBeaconBalance  | uint128 | undefined |
| _newBeaconValidatorCount  | uint32 | undefined |
| _oracleMember `indexed` | address | undefined |

### CLReported

```solidity
event CLReported(uint256 _epochId, uint128 _newCLBalance, uint32 _newCLValidatorCount, address _oracleMember)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId  | uint256 | undefined |
| _newCLBalance  | uint128 | undefined |
| _newCLValidatorCount  | uint32 | undefined |
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

### RemoveMember

```solidity
event RemoveMember(address indexed member)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| member `indexed` | address | undefined |

### SetBounds

```solidity
event SetBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _annualAprUpperBound  | uint256 | undefined |
| _relativeLowerBound  | uint256 | undefined |

### SetMember

```solidity
event SetMember(address indexed oldAddress, address indexed newAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| oldAddress `indexed` | address | undefined |
| newAddress `indexed` | address | undefined |

### SetQuorum

```solidity
event SetQuorum(uint256 _newQuorum)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newQuorum  | uint256 | undefined |

### SetSpec

```solidity
event SetSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochsPerFrame  | uint64 | undefined |
| _slotsPerEpoch  | uint64 | undefined |
| _secondsPerSlot  | uint64 | undefined |
| _genesisTime  | uint64 | undefined |



## Errors

### AddressAlreadyInUse

```solidity
error AddressAlreadyInUse(address _newAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAddress | address | undefined |

### AlreadyReported

```solidity
error AlreadyReported(uint256 _epochId, address _member)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId | uint256 | undefined |
| _member | address | undefined |

### EpochTooOld

```solidity
error EpochTooOld(uint256 _providedEpochId, uint256 _minExpectedEpochId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _providedEpochId | uint256 | undefined |
| _minExpectedEpochId | uint256 | undefined |

### NotFrameFirstEpochId

```solidity
error NotFrameFirstEpochId(uint256 _providedEpochId, uint256 _expectedFrameFirstEpochId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _providedEpochId | uint256 | undefined |
| _expectedFrameFirstEpochId | uint256 | undefined |

### TotalValidatorBalanceDecreaseOutOfBound

```solidity
error TotalValidatorBalanceDecreaseOutOfBound(uint256 _prevTotalEth, uint256 _postTotalEth, uint256 _timeElapsed, uint256 _relativeLowerBound)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _prevTotalEth | uint256 | undefined |
| _postTotalEth | uint256 | undefined |
| _timeElapsed | uint256 | undefined |
| _relativeLowerBound | uint256 | undefined |

### TotalValidatorBalanceIncreaseOutOfBound

```solidity
error TotalValidatorBalanceIncreaseOutOfBound(uint256 _prevTotalEth, uint256 _postTotalEth, uint256 _timeElapsed, uint256 _annualAprUpperBound)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _prevTotalEth | uint256 | undefined |
| _postTotalEth | uint256 | undefined |
| _timeElapsed | uint256 | undefined |
| _annualAprUpperBound | uint256 | undefined |


