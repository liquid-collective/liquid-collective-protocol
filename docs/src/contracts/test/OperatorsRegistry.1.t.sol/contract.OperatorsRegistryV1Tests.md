# OperatorsRegistryV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/OperatorsRegistry.1.t.sol)

**Inherits:**
[OperatorsRegistryV1TestBase](/contracts/test/OperatorsRegistry.1.t.sol/abstract.OperatorsRegistryV1TestBase.md), [OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md), [BytesGenerator](/contracts/test/utils/BytesGenerator.sol/contract.BytesGenerator.md)


## Functions
### setUp


```solidity
function setUp() public;
```

### testInitializeTwice


```solidity
function testInitializeTwice() public;
```

### testForceFundedValidatorKeysEventEmission


```solidity
function testForceFundedValidatorKeysEventEmission() public;
```

### testInternalSetKeys


```solidity
function testInternalSetKeys(uint256 _nodeOperatorAddressSalt, bytes32 _name, uint32 _keyCount, uint32 _blockRoll)
    public;
```

### testAddNodeOperator


```solidity
function testAddNodeOperator(uint256 _nodeOperatorAddressSalt, bytes32 _name) public;
```

### testAddNodeOperatorInvalidAddress


```solidity
function testAddNodeOperatorInvalidAddress(bytes32 _name) public;
```

### testAddNodeOperatorInvalidName


```solidity
function testAddNodeOperatorInvalidName(uint256 _nodeOperatorAddressSalt) public;
```

### testAddNodeWhileNotAdminOperator


```solidity
function testAddNodeWhileNotAdminOperator(uint256 _nodeOperatorAddressSalt, bytes32 _name) public;
```

### testSetOperatorLimitTooHigh


```solidity
function testSetOperatorLimitTooHigh(uint256 _nodeOperatorAddressSalt) public;
```

### testSetOperatorInvariantChecksSkipped


```solidity
function testSetOperatorInvariantChecksSkipped(uint256 _nodeOperatorAddressSalt) public;
```

### testSetOperatorLimitTooLow


```solidity
function testSetOperatorLimitTooLow(uint256 _nodeOperatorAddressSalt) public;
```

### testSetOperatorAddressesAsAdmin


```solidity
function testSetOperatorAddressesAsAdmin(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
    public;
```

### testSetOperatorAddressAsOperator


```solidity
function testSetOperatorAddressAsOperator(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
    public;
```

### testSetOperatorAddressZeroAddr


```solidity
function testSetOperatorAddressZeroAddr(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testSetOperatorAddressAsUnauthorized


```solidity
function testSetOperatorAddressAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
    public;
```

### testSetOperatorNameAsAdmin


```solidity
function testSetOperatorNameAsAdmin(bytes32 _name, uint256 _addressSalt) public;
```

### testSetOperatorNameAsOperator


```solidity
function testSetOperatorNameAsOperator(bytes32 _name, uint256 _addressSalt) public;
```

### testSetOperatorNameEmptyString


```solidity
function testSetOperatorNameEmptyString(bytes32 _name, uint256 _addressSalt) public;
```

### testSetOperatorNameAsUnauthorized


```solidity
function testSetOperatorNameAsUnauthorized(bytes32 _name, uint256 _addressSalt) public;
```

### testOnlyOperatorOrAdmin_AdminCanActOnInactiveOperator


```solidity
function testOnlyOperatorOrAdmin_AdminCanActOnInactiveOperator() public;
```

### testOnlyOperatorOrAdmin_InactiveOperatorCannotCallItself


```solidity
function testOnlyOperatorOrAdmin_InactiveOperatorCannotCallItself() public;
```

### testOnlyOperatorOrAdmin_InactiveOperatorCannotChangeAddress


```solidity
function testOnlyOperatorOrAdmin_InactiveOperatorCannotChangeAddress() public;
```

### testOnlyOperatorOrAdmin_UnauthorizedOnInactiveOperator


```solidity
function testOnlyOperatorOrAdmin_UnauthorizedOnInactiveOperator() public;
```

### testOnlyOperatorOrAdmin_UnauthorizedOnActiveOperator


```solidity
function testOnlyOperatorOrAdmin_UnauthorizedOnActiveOperator() public;
```

### testOnlyOperatorOrAdmin_ActiveOperatorCanCall


```solidity
function testOnlyOperatorOrAdmin_ActiveOperatorCanCall() public;
```

### testOnlyOperatorOrAdmin_AdminCanAddValidatorsForInactiveOperator


```solidity
function testOnlyOperatorOrAdmin_AdminCanAddValidatorsForInactiveOperator() public;
```

### testOnlyOperatorOrAdmin_InactiveOperatorCannotAddValidators


```solidity
function testOnlyOperatorOrAdmin_InactiveOperatorCannotAddValidators() public;
```

### testOnlyOperatorOrAdmin_InactiveOperatorCannotRemoveValidators


```solidity
function testOnlyOperatorOrAdmin_InactiveOperatorCannotRemoveValidators() public;
```

### testOnlyOperatorOrAdmin_AdminCanRemoveValidatorsForInactiveOperator


```solidity
function testOnlyOperatorOrAdmin_AdminCanRemoveValidatorsForInactiveOperator() public;
```

### testSetOperatorStatusAsAdmin


```solidity
function testSetOperatorStatusAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testSetOperatorStatusAsUnauthorized


```solidity
function testSetOperatorStatusAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testSetOperatorLimitCountAsAdmin


```solidity
function testSetOperatorLimitCountAsAdmin(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public;
```

### testSetOperatorLimitCountNoOp


```solidity
function testSetOperatorLimitCountNoOp(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public;
```

### testSetOperatorLimitCountSnapshotTooLow


```solidity
function testSetOperatorLimitCountSnapshotTooLow(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public;
```

### testSetOperatorLimitDecreaseSkipsSnapshotCheck


```solidity
function testSetOperatorLimitDecreaseSkipsSnapshotCheck(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testSetOperatorLimitCountAsUnauthorized


```solidity
function testSetOperatorLimitCountAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public;
```

### testSetOperatorLimitUnorderedOperators


```solidity
function testSetOperatorLimitUnorderedOperators(
    bytes32 _name,
    uint256 _firstAddressSalt,
    uint256 _secondAddressSalt
) public;
```

### testSetOperatorLimitDuplicateOperators


```solidity
function testSetOperatorLimitDuplicateOperators(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testAddValidatorsAsOperator


```solidity
function testAddValidatorsAsOperator(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testGetKeysAsRiver


```solidity
function testGetKeysAsRiver(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testGetKeysAsRiverLimitTest


```solidity
function testGetKeysAsRiverLimitTest(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testGetKeysDistribution


```solidity
function testGetKeysDistribution(uint256 _operatorOneSalt, uint256 _operatorTwoSalt, uint256 _operatorThreeSalt)
    external;
```

### testGetAllActiveOperators


```solidity
function testGetAllActiveOperators(bytes32 _name, uint256 _firstAddressSalt, uint256 _count) public;
```

### testGetAllActiveOperatorsWithInactiveOnes


```solidity
function testGetAllActiveOperatorsWithInactiveOnes(bytes32 _name, uint256 _firstAddressSalt, uint256 _count)
    public;
```

### testPickKeysAsRiverNoKeys


```solidity
function testPickKeysAsRiverNoKeys() public;
```

### testAddValidatorsAsAdmin


```solidity
function testAddValidatorsAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testAddValidatorsAsAdminUnknownOperator


```solidity
function testAddValidatorsAsAdminUnknownOperator(uint256 _index) public;
```

### testAddValidatorsAsUnauthorized


```solidity
function testAddValidatorsAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testAddValidatorsInvalidKeySize


```solidity
function testAddValidatorsInvalidKeySize(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testAddValidatorsInvalidCount


```solidity
function testAddValidatorsInvalidCount(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testRemoveValidatorsAsOperator


```solidity
function testRemoveValidatorsAsOperator(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testRemoveHalfValidatorsEvenCaseAsOperator


```solidity
function testRemoveHalfValidatorsEvenCaseAsOperator(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testRemoveHalfValidatorsConservativeCaseAsOperator


```solidity
function testRemoveHalfValidatorsConservativeCaseAsOperator(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testRemoveValidatorsAsAdmin


```solidity
function testRemoveValidatorsAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testRemoveValidatorsUnauthorized


```solidity
function testRemoveValidatorsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testRemoveValidatorsAndRetrieveAsAdmin


```solidity
function testRemoveValidatorsAndRetrieveAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testRemoveValidatorsFundedKeyRemovalAttempt


```solidity
function testRemoveValidatorsFundedKeyRemovalAttempt(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testRemoveValidatorsKeyOutOfBounds


```solidity
function testRemoveValidatorsKeyOutOfBounds(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testRemoveValidatorsUnsortedIndexes


```solidity
function testRemoveValidatorsUnsortedIndexes(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testRemoveValidatorFail


```solidity
function testRemoveValidatorFail() public;
```

### testGetOperator


```solidity
function testGetOperator(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testGetOperatorCount


```solidity
function testGetOperatorCount(bytes32 _name, uint256 _firstAddressSalt) public;
```

### testOperatorIndexEqualsArrayPosition

Invariant: operator index equals array position; addOperator returns 0, 1, 2, ...


```solidity
function testOperatorIndexEqualsArrayPosition() public;
```

### testOperatorIndicesStableAfterDeactivation

Invariant: indices and count are stable after deactivation (operators are never removed)


```solidity
function testOperatorIndicesStableAfterDeactivation() public;
```

### testGetOperatorOutOfBoundsRevertsWithOperatorNotFound

getOperator(outOfBounds) reverts with OperatorNotFound


```solidity
function testGetOperatorOutOfBoundsRevertsWithOperatorNotFound() public;
```

### testAllocationToInactiveOperatorReverts

Allocation to an inactive operator reverts with InactiveOperator


```solidity
function testAllocationToInactiveOperatorReverts() public;
```

### testFuzzOperatorIndicesSequentialAfterMultipleAdds

Fuzz: operator indices stay 0, 1, ..., n-1 after n adds


```solidity
function testFuzzOperatorIndicesSequentialAfterMultipleAdds(uint8 _n) public;
```

### testGetStoppedValidatorCounts


```solidity
function testGetStoppedValidatorCounts() public;
```

### testReportStoppedValidatorCounts


```solidity
function testReportStoppedValidatorCounts(uint8 totalCount, uint8 len) public;
```

### testReportStoppedValidatorCountsEmptyArray


```solidity
function testReportStoppedValidatorCountsEmptyArray() public;
```

### testReportStoppedValidatorCountsMoreElementsThanOperators


```solidity
function testReportStoppedValidatorCountsMoreElementsThanOperators() public;
```

### testReportStoppedValidatorCountsInvalidSum


```solidity
function testReportStoppedValidatorCountsInvalidSum(uint8 totalCount, uint8 len) public;
```

### testPickValidatorsFromSecondOperatorOnly


```solidity
function testPickValidatorsFromSecondOperatorOnly(
    uint256 _operatorOneSalt,
    uint256 _operatorTwoSalt,
    uint256 _operatorThreeSalt
) public;
```

### testPickValidatorsFromLastOperatorOnly


```solidity
function testPickValidatorsFromLastOperatorOnly(
    uint256 _operatorOneSalt,
    uint256 _operatorTwoSalt,
    uint256 _operatorThreeSalt
) public;
```

### testGetNextValidatorsFromNonFirstOperator


```solidity
function testGetNextValidatorsFromNonFirstOperator(
    uint256 _operatorOneSalt,
    uint256 _operatorTwoSalt,
    uint256 _operatorThreeSalt
) public;
```

### testPickValidatorsIteratesLoopCorrectly


```solidity
function testPickValidatorsIteratesLoopCorrectly() public;
```

### testGetNextValidatorsIteratesLoopCorrectly


```solidity
function testGetNextValidatorsIteratesLoopCorrectly() public;
```

