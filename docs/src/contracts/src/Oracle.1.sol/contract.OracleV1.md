# OracleV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/Oracle.1.sol)

**Inherits:**
[IOracleV1](/contracts/src/interfaces/IOracle.1.sol/interface.IOracleV1.md), [Initializable](/contracts/src/Initializable.sol/contract.Initializable.md), [Administrable](/contracts/src/Administrable.sol/abstract.Administrable.md), [IProtocolVersion](/contracts/src/interfaces/IProtocolVersion.sol/interface.IProtocolVersion.md)

**Title:**
Oracle (v1)

**Author:**
Alluvial Finance Inc.

This contract handles the input from the allowed oracle members. Highly inspired by Lido's implementation.


## Functions
### onlyAdminOrMember


```solidity
modifier onlyAdminOrMember(address _oracleMember) ;
```

### initOracleV1

Initializes the oracle


```solidity
function initOracleV1(
    address _riverAddress,
    address _administratorAddress,
    uint64 _epochsPerFrame,
    uint64 _slotsPerEpoch,
    uint64 _secondsPerSlot,
    uint64 _genesisTime,
    uint256 _annualAprUpperBound,
    uint256 _relativeLowerBound
) external init(0);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_riverAddress`|`address`||
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
function initOracleV1_1() external init(1);
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


```solidity
function addMember(address _newOracleMember, uint256 _newQuorum) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newOracleMember`|`address`|Address of the new member|
|`_newQuorum`|`uint256`|New quorum value|


### removeMember

Removes an address from the oracle members.

Only callable by the adminstrator


```solidity
function removeMember(address _oracleMember, uint256 _newQuorum) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracleMember`|`address`|Address to remove|
|`_newQuorum`|`uint256`|New quorum value|


### setMember

Changes the address of an oracle member

Only callable by the adminitrator or the member itself


```solidity
function setMember(address _oracleMember, address _newAddress) external onlyAdminOrMember(_oracleMember);
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
function setQuorum(uint256 _newQuorum) external onlyAdmin;
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


### _clearReportsAndSetQuorum

Internal utility to clear all the reports and edit the quorum if a new value is provided

Ensures that the quorum respects invariants

The admin is in charge of providing a proper quorum based on the oracle member count

The quorum value Q should respect the following invariant, where O is oracle member count

1 <= Q <= O


```solidity
function _clearReportsAndSetQuorum(uint256 _newQuorum, uint256 _previousQuorum) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newQuorum`|`uint256`|New quorum value|
|`_previousQuorum`|`uint256`|The old quorum value|


### _reportChecksum

Internal utility to hash and retrieve the variant id of a report


```solidity
function _reportChecksum(IRiverV1.ConsensusLayerReport calldata _report) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_report`|`IRiverV1.ConsensusLayerReport`|The reported data structure|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The report variant|


### _clearReports

Internal utility to clear all reporting details


```solidity
function _clearReports() internal;
```

### _getReportVariantIndexAndVotes

Internal utility to retrieve index and vote count for a given variant


```solidity
function _getReportVariantIndexAndVotes(bytes32 _variant) internal view returns (int256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_variant`|`bytes32`|The variant to lookup|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The index of the variant, -1 if not found|
|`<none>`|`uint256`|The vote count of the variant|


### _river

Internal utility to retrieve a casted River interface


```solidity
function _river() internal view returns (IRiverV1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IRiverV1`|The casted River interface|


### version


```solidity
function version() external pure returns (string memory);
```

