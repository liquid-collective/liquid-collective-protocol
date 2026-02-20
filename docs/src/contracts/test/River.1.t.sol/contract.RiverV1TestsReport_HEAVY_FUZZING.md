# RiverV1TestsReport_HEAVY_FUZZING
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/River.1.t.sol)

**Inherits:**
[RiverV1TestBase](/contracts/test/River.1.t.sol/abstract.RiverV1TestBase.md)


## State Variables
### redeemManager

```solidity
RedeemManagerV1 redeemManager
```


### SCENARIO_REGULAR_REPORTING_NOTHING_PULLED

```solidity
uint256 internal constant SCENARIO_REGULAR_REPORTING_NOTHING_PULLED = 0
```


### SCENARIO_REGULAR_REPORTING_PULL_EL_FEES

```solidity
uint256 internal constant SCENARIO_REGULAR_REPORTING_PULL_EL_FEES = 1
```


### SCENARIO_REGULAR_REPORTING_PULL_COVERAGE

```solidity
uint256 internal constant SCENARIO_REGULAR_REPORTING_PULL_COVERAGE = 2
```


### SCENARIO_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER

```solidity
uint256 internal constant SCENARIO_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER = 3
```


### SCENARIO_REGULAR_REPORTING_PULL_HALF_EL_COVERAGE

```solidity
uint256 internal constant SCENARIO_REGULAR_REPORTING_PULL_HALF_EL_COVERAGE = 4
```


### SCENARIO_REGULAR_REPORTING_REBALANCING_MODE_ACTIVE

```solidity
uint256 internal constant SCENARIO_REGULAR_REPORTING_REBALANCING_MODE_ACTIVE = 5
```


### SCENARIO_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE

```solidity
uint256 internal constant SCENARIO_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE = 6
```


## Functions
### setUp


```solidity
function setUp() public override;
```

### _rawPermissions


```solidity
function _rawPermissions(address _who, uint256 _mask) internal;
```

### _allow


```solidity
function _allow(address _who) internal;
```

### _next


```solidity
function _next(uint256 _salt) internal pure returns (uint256 _newSalt);
```

### _performFakeDeposits


```solidity
function _performFakeDeposits(uint8 userCount, uint256 _salt)
    internal
    returns (address[] memory users, uint256 _newSalt);
```

### _performDepositsToConsensusLayer


```solidity
function _performDepositsToConsensusLayer(uint256 _salt)
    internal
    returns (uint256 depositCount, uint256 operatorCount, uint256 _newSalt);
```

### _redeemAllSatisfiedRedeemRequests


```solidity
function _redeemAllSatisfiedRedeemRequests(uint256 _salt) internal returns (uint256);
```

### _performPreAssertions


```solidity
function _performPreAssertions(ReportingFuzzingVariables memory rfv) internal;
```

### _performPostAssertions


```solidity
function _performPostAssertions(ReportingFuzzingVariables memory rfv) internal;
```

### _retrieveInitialReportingData


```solidity
function _retrieveInitialReportingData(ReportingFuzzingVariables memory rfv, uint256 _salt)
    internal
    returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt);
```

### testReportingFuzzing


```solidity
function testReportingFuzzing(uint256 _salt) external;
```

### _retrieveReportingData


```solidity
function _retrieveReportingData(ReportingFuzzingVariables memory rfv, uint256 _salt)
    internal
    returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt);
```

### _updateAssertions


```solidity
function _updateAssertions(
    IOracleManagerV1.ConsensusLayerReport memory clr,
    ReportingFuzzingVariables memory rfv,
    uint256 _salt
) internal;
```

### _retrieveScenario_REGULAR_REPORTING_NOTHING_PULLED


```solidity
function _retrieveScenario_REGULAR_REPORTING_NOTHING_PULLED(ReportingFuzzingVariables memory rfv, uint256 _salt)
    internal
    returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt);
```

### _retrieveScenario_REGULAR_REPORTING_PULL_EL_FEES


```solidity
function _retrieveScenario_REGULAR_REPORTING_PULL_EL_FEES(ReportingFuzzingVariables memory rfv, uint256 _salt)
    internal
    returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt);
```

### _retrieveScenario_REGULAR_REPORTING_PULL_COVERAGE


```solidity
function _retrieveScenario_REGULAR_REPORTING_PULL_COVERAGE(ReportingFuzzingVariables memory rfv, uint256 _salt)
    internal
    returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt);
```

### _retrieveScenario_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER


```solidity
function _retrieveScenario_REGULAR_REPORTING_PULL_EXCEEDING_BUFFER(
    ReportingFuzzingVariables memory rfv,
    uint256 _salt
) internal returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt);
```

### _retrieveScenario_REGULAR_REPORTING_PULL_HALF_EL_COVERAGE


```solidity
function _retrieveScenario_REGULAR_REPORTING_PULL_HALF_EL_COVERAGE(
    ReportingFuzzingVariables memory rfv,
    uint256 _salt
) internal returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt);
```

### _retrieveScenario_REGULAR_REPORTING_REBALANCING_MODE_ACTIVE


```solidity
function _retrieveScenario_REGULAR_REPORTING_REBALANCING_MODE_ACTIVE(
    ReportingFuzzingVariables memory rfv,
    uint256 _salt
) internal returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt);
```

### _retrieveScenario_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE


```solidity
function _retrieveScenario_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE(
    ReportingFuzzingVariables memory rfv,
    uint256 _salt
) internal returns (IOracleManagerV1.ConsensusLayerReport memory clr, uint256 _newSalt);
```

### _updateAssertions_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE


```solidity
function _updateAssertions_REGULAR_REPORTING_SLASHING_CONTAINMENT_ACTIVE(
    ReportingFuzzingVariables memory,
    IOracleManagerV1.ConsensusLayerReport memory clr,
    uint256
) internal;
```

### debug_maxIncrease


```solidity
function debug_maxIncrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth, uint256 _timeElapsed)
    internal
    pure
    returns (uint256);
```

### debug_maxDecrease


```solidity
function debug_maxDecrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth)
    internal
    pure
    returns (uint256);
```

### debug_timeBetweenEpochs


```solidity
function debug_timeBetweenEpochs(CLSpec.CLSpecStruct memory cls, uint256 epochPast, uint256 epochNow)
    internal
    pure
    returns (uint256);
```

### _generateEmptyReport


```solidity
function _generateEmptyReport() internal pure returns (IOracleManagerV1.ConsensusLayerReport memory clr);
```

### testReportingError_Unauthorized


```solidity
function testReportingError_Unauthorized(uint256 _salt) external;
```

### testReportingError_InvalidEpoch


```solidity
function testReportingError_InvalidEpoch(uint256 _salt) external;
```

### _depositValidators


```solidity
function _depositValidators(uint256 count, uint256 _salt) internal returns (uint256);
```

### testReportingError_InvalidValidatorCountReport


```solidity
function testReportingError_InvalidValidatorCountReport(uint256 _salt) external;
```

### testReportingError_InvalidDecreasingValidatorsExitedBalance


```solidity
function testReportingError_InvalidDecreasingValidatorsExitedBalance(uint256 _salt) external;
```

### testReportingError_InvalidDecreasingValidatorsSkimmedBalance


```solidity
function testReportingError_InvalidDecreasingValidatorsSkimmedBalance(uint256 _salt) external;
```

### testReportingError_TotalValidatorBalanceIncreaseOutOfBound


```solidity
function testReportingError_TotalValidatorBalanceIncreaseOutOfBound(uint256 _salt) external;
```

### testReportingError_TotalValidatorBalanceDecreaseOutOfBound


```solidity
function testReportingError_TotalValidatorBalanceDecreaseOutOfBound(uint256 _salt) external;
```

### testReportingError_ValidatorCountDecreasing


```solidity
function testReportingError_ValidatorCountDecreasing(uint256 _salt) external;
```

### testReportingError_ValidatorCountHigherThanDeposits


```solidity
function testReportingError_ValidatorCountHigherThanDeposits(uint256 _salt) external;
```

### testReportingError_InvalidPulledClFundsAmount


```solidity
function testReportingError_InvalidPulledClFundsAmount(uint256 _salt) external;
```

### testReportingError_StoppedValidatorCountDecreasing


```solidity
function testReportingError_StoppedValidatorCountDecreasing(uint256 _salt) external;
```

### _computeCommittedAmount


```solidity
function _computeCommittedAmount(
    uint256 epochStart,
    uint256 epochReported,
    uint256 initialCommittedAmount,
    uint256 initialDepositAmount,
    uint256 extraBalanceToDeposit
) internal view returns (uint256);
```

### testReportingSuccess_AssertCommittedAmountAfterSkimming


```solidity
function testReportingSuccess_AssertCommittedAmountAfterSkimming(uint256 _salt) external;
```

### testReportingSuccess_AssertCommittedAmountAfterELFees


```solidity
function testReportingSuccess_AssertCommittedAmountAfterELFees(uint256 _salt) external;
```

### testReportingSuccess_AssertCommittedAmountAfterCoverage


```solidity
function testReportingSuccess_AssertCommittedAmountAfterCoverage(uint256 _salt) external;
```

### testReportingSuccess_AssertCommittedAmountAfterMultiPulling


```solidity
function testReportingSuccess_AssertCommittedAmountAfterMultiPulling(uint256 _salt) external;
```

### testExternalViewFunctions


```solidity
function testExternalViewFunctions() public;
```

## Structs
### ReportingFuzzingVariables

```solidity
struct ReportingFuzzingVariables {
    address[] users;
    uint256 depositCount;
    uint256 scenario;
    uint256 operatorCount;
    CLSpec.CLSpecStruct cls;
    ReportBounds.ReportBoundsStruct rb;
    uint256 expected_pre_elFeeRecipientBalance;
    uint256 expected_pre_coverageFundBalance;
    uint256 expected_pre_exceedingBufferAmount;
    uint256 expected_post_elFeeRecipientBalance;
    uint256 expected_post_coverageFundBalance;
    uint256 expected_post_exceedingBufferAmount;
}
```

