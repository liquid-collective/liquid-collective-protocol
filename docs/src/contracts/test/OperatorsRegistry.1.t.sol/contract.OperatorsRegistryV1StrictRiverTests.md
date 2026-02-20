# OperatorsRegistryV1StrictRiverTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/OperatorsRegistry.1.t.sol)

**Inherits:**
[OperatorsRegistryV1TestBase](/contracts/test/OperatorsRegistry.1.t.sol/abstract.OperatorsRegistryV1TestBase.md), [OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md), [BytesGenerator](/contracts/test/utils/BytesGenerator.sol/contract.BytesGenerator.md)

Tests that require real onlyRiver enforcement (expect Unauthorized when not pranking as river)


## Functions
### setUp


```solidity
function setUp() public;
```

### testPickNextValidatorsToDepositRevertsWithUnauthorizedWhenNotRiver


```solidity
function testPickNextValidatorsToDepositRevertsWithUnauthorizedWhenNotRiver() public;
```

### testReportStoppedValidatorCountsUnauthorized


```solidity
function testReportStoppedValidatorCountsUnauthorized(uint256 _salt, uint32 totalCount, uint8 len) public;
```

### testGetKeysAsUnauthorized


```solidity
function testGetKeysAsUnauthorized() public;
```

