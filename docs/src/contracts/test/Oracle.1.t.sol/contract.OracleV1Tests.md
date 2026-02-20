# OracleV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/Oracle.1.t.sol)

**Inherits:**
[OracleV1TestBase](/contracts/test/Oracle.1.t.sol/abstract.OracleV1TestBase.md)


## Functions
### setUp


```solidity
function setUp() public override;
```

### testGetAdmin


```solidity
function testGetAdmin() public view;
```

### testGetRiver


```solidity
function testGetRiver() public view;
```

### testSetQuorum


```solidity
function testSetQuorum(uint256 newMemberSalt, uint256 anotherMemberSalt) public;
```

### testSetQuorumUnauthorized


```solidity
function testSetQuorumUnauthorized(uint256 newMemberSalt, uint256 anotherMemberSalt) public;
```

### testAddMemberQuorumZero


```solidity
function testAddMemberQuorumZero() public;
```

### testRemoveMemberQuorumZero


```solidity
function testRemoveMemberQuorumZero() public;
```

### testGetMemberStatusRandomAddress


```solidity
function testGetMemberStatusRandomAddress(uint256 newMemberSalt) public;
```

### testAddMember


```solidity
function testAddMember(uint256 newMemberSalt) public;
```

### testAddMemberQuorumEvent


```solidity
function testAddMemberQuorumEvent(uint256 newMemberSalt) public;
```

### testAddMemberUnauthorized


```solidity
function testAddMemberUnauthorized(uint256 newMemberSalt) public;
```

### testAddMemberExisting


```solidity
function testAddMemberExisting(uint256 newMemberSalt) public;
```

### testRemoveMember


```solidity
function testRemoveMember(uint256 newMemberSalt) public;
```

### testRemoveMemberQuorumEvent


```solidity
function testRemoveMemberQuorumEvent(uint256 newMemberSalt) public;
```

### testEditMember


```solidity
function testEditMember(uint256 newMemberSalt, uint256 newAddressSalt) public;
```

### testEditMemberZero


```solidity
function testEditMemberZero(uint256 newMemberSalt) public;
```

### testEditMemberAlreadyInUse


```solidity
function testEditMemberAlreadyInUse(uint256 newMemberSalt) public;
```

### testEditMemberAsMember


```solidity
function testEditMemberAsMember(uint256 newMemberSalt, uint256 newAddressSalt) public;
```

### testEditMemberUnauthorized


```solidity
function testEditMemberUnauthorized(uint256 newMemberSalt, uint256 newAddressSalt) public;
```

### testEditMemberNotFound


```solidity
function testEditMemberNotFound(uint256 newMemberSalt, uint256 newAddressSalt) public;
```

### testRemoveMemberUnauthorized


```solidity
function testRemoveMemberUnauthorized(uint256 newMemberSalt) public;
```

### testRemoveMemberInvalidCall


```solidity
function testRemoveMemberInvalidCall() public;
```

### testSetQuorumRedundant


```solidity
function testSetQuorumRedundant(uint256 oracleMemberSalt) public;
```

### testSetQuorumTooHigh


```solidity
function testSetQuorumTooHigh() public;
```

### _generateEmptyReport


```solidity
function _generateEmptyReport(uint256 stoppedValidatorsCountElements)
    internal
    pure
    returns (IOracleManagerV1.ConsensusLayerReport memory clr);
```

### testValidReport


```solidity
function testValidReport(uint256 _salt) external;
```

### testValidReportMultiVote


```solidity
function testValidReportMultiVote(uint256 _salt) external;
```

### testRevoteAfterSetMember


```solidity
function testRevoteAfterSetMember(uint256 _salt) external;
```

### testReportUnauthorized


```solidity
function testReportUnauthorized(uint256 _salt) external;
```

### testReportEpochTooOld


```solidity
function testReportEpochTooOld(uint256 _salt) external;
```

### testReportEpochInvalidEpoch


```solidity
function testReportEpochInvalidEpoch(uint256 _salt) external;
```

### testValidReportAlreadyReported


```solidity
function testValidReportAlreadyReported(uint256 _salt) external;
```

### testValidReportClearOnNewReport


```solidity
function testValidReportClearOnNewReport(uint256 _salt) external;
```

### testValidReportEpochTooOldAfterClear


```solidity
function testValidReportEpochTooOldAfterClear(uint256 _salt) external;
```

### testValidReportClearedAfterNewMemberAdded


```solidity
function testValidReportClearedAfterNewMemberAdded(uint256 _salt) external;
```

### testValidReportClearedAfterMemberRemoved


```solidity
function testValidReportClearedAfterMemberRemoved(uint256 _salt) external;
```

### _next


```solidity
function _next(uint256 _salt) internal pure returns (uint256);
```

### testVoteFuzzing


```solidity
function testVoteFuzzing(uint256 _salt) external;
```

### testGetReportVariantDetails


```solidity
function testGetReportVariantDetails() external;
```

### testGetReportVariantDetailsFail


```solidity
function testGetReportVariantDetailsFail() external;
```

### testExternalViewFunctions


```solidity
function testExternalViewFunctions() external;
```

### testGetReportVariantCount


```solidity
function testGetReportVariantCount() external;
```

### testVersion


```solidity
function testVersion() external;
```

## Events
### DebugReceivedReport

```solidity
event DebugReceivedReport(IOracleManagerV1.ConsensusLayerReport report);
```

### ClearedReporting

```solidity
event ClearedReporting();
```

### SetLastReportedEpoch

```solidity
event SetLastReportedEpoch(uint256 lastReportedEpoch);
```

