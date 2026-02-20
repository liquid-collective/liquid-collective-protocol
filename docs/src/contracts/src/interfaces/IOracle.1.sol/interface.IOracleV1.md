# IOracleV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/IOracle.1.sol)

**Title:**
Oracle Interface (v1)

**Author:**
Alluvial Finance Inc.

This interface exposes methods to handle the input from the allowed oracle members.

Highly inspired by Lido's implementation.


## Functions
### initOracleV1

Initializes the oracle


```solidity
function initOracleV1(
    address _river,
    address _administratorAddress,
    uint64 _epochsPerFrame,
    uint64 _slotsPerEpoch,
    uint64 _secondsPerSlot,
    uint64 _genesisTime,
    uint256 _annualAprUpperBound,
    uint256 _relativeLowerBound
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_river`|`address`|Address of the River contract, able to receive oracle input data after quorum is met|
|`_administratorAddress`|`address`|Address able to call administrative methods|
|`_epochsPerFrame`|`uint64`|CL spec parameter. Number of epochs in a frame.|
|`_slotsPerEpoch`|`uint64`|CL spec parameter. Number of slots in one epoch.|
|`_secondsPerSlot`|`uint64`|CL spec parameter. Number of seconds between slots.|
|`_genesisTime`|`uint64`|CL spec parameter. Timestamp of the genesis slot.|
|`_annualAprUpperBound`|`uint256`|CL bound parameter. Maximum apr allowed for balance increase. Delta between updates is extrapolated on a year time frame.|
|`_relativeLowerBound`|`uint256`|CL bound parameter. Maximum relative balance decrease.|


### initOracleV1_1

Initializes the oracle


```solidity
function initOracleV1_1() external;
```

### getRiver

Retrieve River address


```solidity
function getRiver() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of River|


### getMemberReportStatus

Retrieve member report status


```solidity
function getMemberReportStatus(address _oracleMember) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracleMember`|`address`|Address of member to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if member has reported|


### getGlobalReportStatus

Retrieve member report status


```solidity
function getGlobalReportStatus() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The raw report status value|


### getReportVariantsCount

Retrieve report variants count


```solidity
function getReportVariantsCount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The count of report variants|


### getReportVariantDetails

Retrieve the details of a report variant


```solidity
function getReportVariantDetails(uint256 _idx) external view returns (ReportsVariants.ReportVariantDetails memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_idx`|`uint256`|The index of the report variant|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ReportsVariants.ReportVariantDetails`|The report variant details|


### getQuorum

Retrieve the current quorum


```solidity
function getQuorum() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current quorum|


### getOracleMembers

Retrieve the list of oracle members


```solidity
function getOracleMembers() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|The oracle members|


### isMember

Returns true if address is member

Performs a naive search, do not call this on-chain, used as an off-chain helper


```solidity
function isMember(address _memberAddress) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|Address of the member|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if address is a member|


### getLastReportedEpochId

Retrieve the last reported epoch id

The Oracle contracts expects reports on an epoch id >= that the returned value


```solidity
function getLastReportedEpochId() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The last reported epoch id|


### addMember

Adds new address as oracle member, giving the ability to push cl reports.

Only callable by the adminstrator

Modifying the quorum clears all the reporting data


```solidity
function addMember(address _newOracleMember, uint256 _newQuorum) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newOracleMember`|`address`|Address of the new member|
|`_newQuorum`|`uint256`|New quorum value|


### removeMember

Removes an address from the oracle members.

Only callable by the adminstrator

Modifying the quorum clears all the reporting data

Remaining members that have already voted should vote again for the same frame.


```solidity
function removeMember(address _oracleMember, uint256 _newQuorum) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracleMember`|`address`|Address to remove|
|`_newQuorum`|`uint256`|New quorum value|


### setMember

Changes the address of an oracle member

Only callable by the adminitrator or the member itself

Cannot use an address already in use


```solidity
function setMember(address _oracleMember, address _newAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracleMember`|`address`|Address to change|
|`_newAddress`|`address`|New address for the member|


### setQuorum

Edits the quorum required to forward cl data to River

Modifying the quorum clears all the reporting data


```solidity
function setQuorum(uint256 _newQuorum) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newQuorum`|`uint256`|New quorum parameter|


### reportConsensusLayerData

Submit a report as an oracle member


```solidity
function reportConsensusLayerData(IRiverV1.ConsensusLayerReport calldata _report) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_report`|`IRiverV1.ConsensusLayerReport`|The report structure|


## Events
### SetQuorum
The storage quorum value has been changed


```solidity
event SetQuorum(uint256 newQuorum);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newQuorum`|`uint256`|The new quorum value|

### AddMember
A member has been added to the oracle member list


```solidity
event AddMember(address indexed member);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The address of the member|

### RemoveMember
A member has been removed from the oracle member list


```solidity
event RemoveMember(address indexed member);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The address of the member|

### SetMember
A member address has been edited


```solidity
event SetMember(address indexed oldAddress, address indexed newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAddress`|`address`|The previous member address|
|`newAddress`|`address`|The new member address|

### SetRiver
The storage river address value has been changed


```solidity
event SetRiver(address _river);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_river`|`address`|The new river address|

### SetSpec
The consensus layer spec has been changed


```solidity
event SetSpec(uint64 epochsPerFrame, uint64 slotsPerEpoch, uint64 secondsPerSlot, uint64 genesisTime);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epochsPerFrame`|`uint64`|The number of epochs inside a frame (225 = 24 hours)|
|`slotsPerEpoch`|`uint64`|The number of slots inside an epoch (32 on ethereum mainnet)|
|`secondsPerSlot`|`uint64`|The time between two slots (12 seconds on ethereum mainnet)|
|`genesisTime`|`uint64`|The timestamp of block #0|

### SetBounds
The report bounds have been changed


```solidity
event SetBounds(uint256 annualAprUpperBound, uint256 relativeLowerBound);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`annualAprUpperBound`|`uint256`|The maximum allowed apr. 10% means increases in balance extrapolated to a year should not exceed 10%.|
|`relativeLowerBound`|`uint256`|The maximum allowed balance decrease as a relative % of the total balance|

### ReportedConsensusLayerData
An oracle member performed a report


```solidity
event ReportedConsensusLayerData(
    address indexed member,
    bytes32 indexed variant,
    IRiverV1.ConsensusLayerReport report,
    uint256 voteCount,
    uint256 quorum
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The oracle member|
|`variant`|`bytes32`|The variant of the report|
|`report`|`IRiverV1.ConsensusLayerReport`|The raw report structure|
|`voteCount`|`uint256`|The vote count|
|`quorum`|`uint256`||

### SetLastReportedEpoch
The last reported epoch has changed


```solidity
event SetLastReportedEpoch(uint256 lastReportedEpoch);
```

### ClearedReporting
Cleared reporting data


```solidity
event ClearedReporting();
```

## Errors
### EpochTooOld
The provided epoch is too old compared to the expected epoch id


```solidity
error EpochTooOld(uint256 providedEpochId, uint256 minExpectedEpochId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`providedEpochId`|`uint256`|The epoch id provided as input|
|`minExpectedEpochId`|`uint256`|The minimum epoch id expected|

### InvalidEpoch
Thrown when the reported epoch is invalid


```solidity
error InvalidEpoch(uint256 epoch);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epoch`|`uint256`|The invalid epoch|

### ReportIndexOutOfBounds
Thrown when the report indexs fetched is out of bounds


```solidity
error ReportIndexOutOfBounds(uint256 index, uint256 length);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|Requested index|
|`length`|`uint256`|Size of the variant array|

### AlreadyReported
The member already reported on the given epoch id


```solidity
error AlreadyReported(uint256 epochId, address member);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epochId`|`uint256`|The epoch id provided as input|
|`member`|`address`|The oracle member|

### AddressAlreadyInUse
The address is already in use by an oracle member


```solidity
error AddressAlreadyInUse(address newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newAddress`|`address`|The address already in use|

