# IOracleManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/components/IOracleManager.1.sol)

**Title:**
Oracle Manager (v1)

**Author:**
Alluvial Finance Inc.

This interface exposes methods to handle the inputs provided by the oracle


## Functions
### getOracle

Get oracle address


```solidity
function getOracle() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The oracle address|


### getCLValidatorTotalBalance

Get CL validator total balance


```solidity
function getCLValidatorTotalBalance() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The CL Validator total balance|


### getCLValidatorCount

Get CL validator count (the amount of validator reported by the oracles)


```solidity
function getCLValidatorCount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The CL validator count|


### isValidEpoch

Verifies if the provided epoch is valid


```solidity
function isValidEpoch(uint256 epoch) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epoch`|`uint256`|The epoch to lookup|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if valid|


### getTime

Retrieve the block timestamp


```solidity
function getTime() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current timestamp from the EVM context|


### getExpectedEpochId

Retrieve expected epoch id


```solidity
function getExpectedEpochId() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current expected epoch id|


### getLastCompletedEpochId

Retrieve the last completed epoch id


```solidity
function getLastCompletedEpochId() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The last completed epoch id|


### getCurrentEpochId

Retrieve the current epoch id based on block timestamp


```solidity
function getCurrentEpochId() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current epoch id|


### getCLSpec

Retrieve the current cl spec


```solidity
function getCLSpec() external view returns (CLSpec.CLSpecStruct memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CLSpec.CLSpecStruct`|The Consensus Layer Specification|


### getCurrentFrame

Retrieve the current frame details


```solidity
function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_startEpochId`|`uint256`|The epoch at the beginning of the frame|
|`_startTime`|`uint256`|The timestamp of the beginning of the frame in seconds|
|`_endTime`|`uint256`|The timestamp of the end of the frame in seconds|


### getFrameFirstEpochId

Retrieve the first epoch id of the frame of the provided epoch id


```solidity
function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_epochId`|`uint256`|Epoch id used to get the frame|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The first epoch id of the frame containing the given epoch id|


### getReportBounds

Retrieve the report bounds


```solidity
function getReportBounds() external view returns (ReportBounds.ReportBoundsStruct memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ReportBounds.ReportBoundsStruct`|The report bounds|


### getLastConsensusLayerReport

Retrieve the last consensus layer report


```solidity
function getLastConsensusLayerReport() external view returns (IOracleManagerV1.StoredConsensusLayerReport memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IOracleManagerV1.StoredConsensusLayerReport`|The stored consensus layer report|


### setOracle

Set the oracle address


```solidity
function setOracle(address _oracleAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracleAddress`|`address`|Address of the oracle|


### setCLSpec

Set the consensus layer spec


```solidity
function setCLSpec(CLSpec.CLSpecStruct calldata _newValue) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`CLSpec.CLSpecStruct`|The new consensus layer spec value|


### setReportBounds

Set the report bounds


```solidity
function setReportBounds(ReportBounds.ReportBoundsStruct calldata _newValue) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`ReportBounds.ReportBoundsStruct`|The new report bounds value|


### setConsensusLayerData

Performs all the reporting logics


```solidity
function setConsensusLayerData(ConsensusLayerReport calldata _report) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_report`|`ConsensusLayerReport`|The consensus layer report structure|


## Events
### SetOracle
The stored oracle address changed


```solidity
event SetOracle(address indexed oracleAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oracleAddress`|`address`|The new oracle address|

### ConsensusLayerDataUpdate
The consensus layer data provided by the oracle has been updated


```solidity
event ConsensusLayerDataUpdate(uint256 validatorCount, uint256 validatorTotalBalance, bytes32 roundId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`validatorCount`|`uint256`|The new count of validators running on the consensus layer|
|`validatorTotalBalance`|`uint256`|The new total balance sum of all validators|
|`roundId`|`bytes32`|Round identifier|

### SetSpec
The Consensus Layer Spec is changed


```solidity
event SetSpec(
    uint64 epochsPerFrame,
    uint64 slotsPerEpoch,
    uint64 secondsPerSlot,
    uint64 genesisTime,
    uint64 epochsToAssumedFinality
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epochsPerFrame`|`uint64`|The number of epochs inside a frame|
|`slotsPerEpoch`|`uint64`|The number of slots inside an epoch|
|`secondsPerSlot`|`uint64`|The number of seconds inside a slot|
|`genesisTime`|`uint64`|The genesis timestamp|
|`epochsToAssumedFinality`|`uint64`|The number of epochs before an epoch is considered final|

### SetBounds
The Report Bounds are changed


```solidity
event SetBounds(uint256 annualAprUpperBound, uint256 relativeLowerBound);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`annualAprUpperBound`|`uint256`|The reporting upper bound|
|`relativeLowerBound`|`uint256`|The reporting lower bound|

### ProcessedConsensusLayerReport
The provided report has beend processed


```solidity
event ProcessedConsensusLayerReport(
    IOracleManagerV1.ConsensusLayerReport report, ConsensusLayerDataReportingTrace trace
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`report`|`IOracleManagerV1.ConsensusLayerReport`|The report that was provided|
|`trace`|`ConsensusLayerDataReportingTrace`|The trace structure providing more insights on internals|

## Errors
### InvalidValidatorCountReport
The reported validator count is invalid


```solidity
error InvalidValidatorCountReport(
    uint256 providedValidatorCount, uint256 depositedValidatorCount, uint256 lastReportedValidatorCount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`providedValidatorCount`|`uint256`|The received validator count value|
|`depositedValidatorCount`|`uint256`|The number of deposits performed by the system|
|`lastReportedValidatorCount`|`uint256`|The last reported validator count|

### InvalidEpoch
Thrown when an invalid epoch was reported


```solidity
error InvalidEpoch(uint256 epoch);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epoch`|`uint256`|Invalid epoch|

### TotalValidatorBalanceIncreaseOutOfBound
The balance increase is higher than the maximum allowed by the upper bound


```solidity
error TotalValidatorBalanceIncreaseOutOfBound(
    uint256 prevTotalEthIncludingExited,
    uint256 postTotalEthIncludingExited,
    uint256 timeElapsed,
    uint256 annualAprUpperBound
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`prevTotalEthIncludingExited`|`uint256`|The previous total balance, including all exited balance|
|`postTotalEthIncludingExited`|`uint256`|The post-report total balance, including all exited balance|
|`timeElapsed`|`uint256`|The time in seconds since last report|
|`annualAprUpperBound`|`uint256`|The upper bound value that was used|

### TotalValidatorBalanceDecreaseOutOfBound
The balance decrease is higher than the maximum allowed by the lower bound


```solidity
error TotalValidatorBalanceDecreaseOutOfBound(
    uint256 prevTotalEthIncludingExited,
    uint256 postTotalEthIncludingExited,
    uint256 timeElapsed,
    uint256 relativeLowerBound
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`prevTotalEthIncludingExited`|`uint256`|The previous total balance, including all exited balance|
|`postTotalEthIncludingExited`|`uint256`|The post-report total balance, including all exited balance|
|`timeElapsed`|`uint256`|The time in seconds since last report|
|`relativeLowerBound`|`uint256`|The lower bound value that was used|

### InvalidDecreasingValidatorsExitedBalance
The total exited balance decreased


```solidity
error InvalidDecreasingValidatorsExitedBalance(
    uint256 currentValidatorsExitedBalance, uint256 newValidatorsExitedBalance
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentValidatorsExitedBalance`|`uint256`|The current exited balance|
|`newValidatorsExitedBalance`|`uint256`|The new exited balance|

### InvalidDecreasingValidatorsSkimmedBalance
The total skimmed balance decreased


```solidity
error InvalidDecreasingValidatorsSkimmedBalance(
    uint256 currentValidatorsSkimmedBalance, uint256 newValidatorsSkimmedBalance
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentValidatorsSkimmedBalance`|`uint256`|The current exited balance|
|`newValidatorsSkimmedBalance`|`uint256`|The new exited balance|

## Structs
### ConsensusLayerDataReportingTrace
Trace structure emitted via logs during reporting


```solidity
struct ConsensusLayerDataReportingTrace {
    uint256 rewards;
    uint256 pulledELFees;
    uint256 pulledRedeemManagerExceedingEthBuffer;
    uint256 pulledCoverageFunds;
}
```

### ConsensusLayerReport
The format of the oracle report


```solidity
struct ConsensusLayerReport {
    // this is the epoch at which the report was performed
    // data should be fetched up to the state of this epoch by the oracles
    uint256 epoch;
    // the sum of all the validator balances on the consensus layer
    // when a validator enters the exit queue, the validator is considered stopped, its balance is accounted in both validatorsExitingBalance and validatorsBalance
    // when a validator leaves the exit queue and the funds are sweeped onto the execution layer, the balance is only accounted in validatorsExitedBalance and not in validatorsBalance
    // this value can decrease between reports
    uint256 validatorsBalance;
    // the sum of all the skimmings performed on the validators
    // these values can be found in the execution layer block bodies under the withdrawals field
    // a withdrawal is considered skimming if
    // - the epoch at which it happened is < validator.withdrawableEpoch
    // - the epoch at which it happened is >= validator.withdrawableEpoch and in that case we only account for what would be above 32 eth as skimming
    // this value cannot decrease over reports
    uint256 validatorsSkimmedBalance;
    // the sum of all the exits performed on the validators
    // these values can be found in the execution layer block bodies under the withdrawals field
    // a withdrawal is considered exit if
    // - the epoch at which it happened is >= validator.withdrawableEpoch and in that case we only account for what would be <= 32 eth as exit
    // this value cannot decrease over reports
    uint256 validatorsExitedBalance;
    // the sum of all the exiting balance, which is all the validators on their way to get sweeped and exited
    // this includes voluntary exits and slashings
    // this value can decrease between reports
    uint256 validatorsExitingBalance;
    // the count of activated validators
    // even validators that are exited are still accounted
    // this value cannot decrease over reports
    uint32 validatorsCount;
    // an array containing the count of stopped validators per operator
    // the first element of the array is the sum of all stopped validators
    // then index 1 would be operator 0
    // these values cannot decrease over reports
    uint32[] stoppedValidatorCountPerOperator;
    // flag enabled by the oracles when the buffer rebalancing is activated
    // the activation logic is written in the oracle specification and all oracle members must agree on the activation
    // when active, the eth in the deposit buffer can be used to pay for exits in the redeem manager
    bool rebalanceDepositToRedeemMode;
    // flag enabled by the oracles when the slashing containment is activated
    // the activation logic is written in the oracle specification and all oracle members must agree on the activation
    // This flag is activated when a pre-defined threshold of slashed validators in our set of validators is reached
    // This flag is deactivated when a bottom threshold is met, this means that when we reach the upper threshold and activate the flag, we will deactivate it when we reach the bottom threshold and not before
    // when active, no more validator exits can be requested by the protocol
    bool slashingContainmentMode;
}
```

### StoredConsensusLayerReport
The format of the oracle report in storage

These fields have the exact same function as the ones in ConsensusLayerReport, but this struct is optimized for storage


```solidity
struct StoredConsensusLayerReport {
    uint256 epoch;
    uint256 validatorsBalance;
    uint256 validatorsSkimmedBalance;
    uint256 validatorsExitedBalance;
    uint256 validatorsExitingBalance;
    uint32 validatorsCount;
    bool rebalanceDepositToRedeemMode;
    bool slashingContainmentMode;
}
```

