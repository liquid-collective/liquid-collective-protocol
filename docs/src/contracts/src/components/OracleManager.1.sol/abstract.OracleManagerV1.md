# OracleManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/components/OracleManager.1.sol)

**Inherits:**
[IOracleManagerV1](/contracts/src/interfaces/components/IOracleManager.1.sol/interface.IOracleManagerV1.md)

**Title:**
Oracle Manager (v1)

**Author:**
Alluvial Finance Inc.

This contract handles the inputs provided by the oracle

The Oracle contract is plugged to this contract and is in charge of pushing

data whenever a new report has been deemed valid. The report consists in two

values: the sum of all balances of all deposited validators and the count of

validators that have been activated on the consensus layer.


## State Variables
### ONE_YEAR

```solidity
uint256 internal constant ONE_YEAR = 365 days
```


### _DEPOSIT_SIZE
Size of a deposit in ETH


```solidity
uint256 public constant _DEPOSIT_SIZE = 32 ether
```


## Functions
### _onEarnings

Handler called if the delta between the last and new validator balance sum is positive

Must be overridden


```solidity
function _onEarnings(uint256 _profits) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_profits`|`uint256`|The positive increase in the validator balance sum (staking rewards)|


### _pullELFees

Handler called to pull the Execution layer fees from the recipient

Must be overridden


```solidity
function _pullELFees(uint256 _max) internal virtual returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_max`|`uint256`|The maximum amount to pull inside the system|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount pulled inside the system|


### _pullCoverageFunds

Handler called to pull the coverage funds

Must be overridden


```solidity
function _pullCoverageFunds(uint256 _max) internal virtual returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_max`|`uint256`|The maximum amount to pull inside the system|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount pulled inside the system|


### _getRiverAdmin

Handler called to retrieve the system administrator address

Must be overridden


```solidity
function _getRiverAdmin() internal view virtual returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The system administrator address|


### _assetBalance

Overridden handler called whenever the total balance of ETH is requested


```solidity
function _assetBalance() internal view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current total asset balance managed by River|


### _pullCLFunds

Pulls funds from the Withdraw contract, and adds funds to deposit and redeem balances


```solidity
function _pullCLFunds(uint256 _skimmedEthAmount, uint256 _exitedEthAmount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_skimmedEthAmount`|`uint256`|The new amount of skimmed eth to pull|
|`_exitedEthAmount`|`uint256`|The new amount of exited eth to pull|


### _pullRedeemManagerExceedingEth

Pulls funds from the redeem manager exceeding eth buffer


```solidity
function _pullRedeemManagerExceedingEth(uint256 _max) internal virtual returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_max`|`uint256`|The maximum amount to pull|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount pulled|


### _reportWithdrawToRedeemManager

Use the balance to redeem to report a withdrawal event on the redeem manager


```solidity
function _reportWithdrawToRedeemManager() internal virtual;
```

### _requestExitsBasedOnRedeemDemandAfterRebalancings

Requests exits of validators after possibly rebalancing deposit and redeem balances


```solidity
function _requestExitsBasedOnRedeemDemandAfterRebalancings(
    uint256 _exitingBalance,
    uint32[] memory _stoppedValidatorCounts,
    bool _depositToRedeemRebalancingAllowed,
    bool _slashingContainmentModeEnabled
) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_exitingBalance`|`uint256`|The currently exiting funds, soon to be received on the execution layer|
|`_stoppedValidatorCounts`|`uint32[]`||
|`_depositToRedeemRebalancingAllowed`|`bool`|True if rebalancing from deposit to redeem is allowed|
|`_slashingContainmentModeEnabled`|`bool`||


### _skimExcessBalanceToRedeem

Skims the redeem balance and sends remaining funds to the deposit balance


```solidity
function _skimExcessBalanceToRedeem() internal virtual;
```

### _commitBalanceToDeposit

Commits the deposit balance up to the allowed daily limit


```solidity
function _commitBalanceToDeposit(uint256 _period) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_period`|`uint256`|The period between current and last report|


### onlyAdmin_OMV1

Prevents unauthorized calls


```solidity
modifier onlyAdmin_OMV1() ;
```

### initOracleManagerV1

Set the initial oracle address


```solidity
function initOracleManagerV1(address _oracle) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracle`|`address`|Address of the oracle|


### initOracleManagerV1_1

Initializes version 1.1 of the oracle manager


```solidity
function initOracleManagerV1_1(
    uint64 _epochsPerFrame,
    uint64 _slotsPerEpoch,
    uint64 _secondsPerSlot,
    uint64 _genesisTime,
    uint64 _epochsToAssumedFinality,
    uint256 _annualAprUpperBound,
    uint256 _relativeLowerBound
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_epochsPerFrame`|`uint64`|The amounts of epochs in a frame|
|`_slotsPerEpoch`|`uint64`|The slots inside an epoch|
|`_secondsPerSlot`|`uint64`|The seconds inside a slot|
|`_genesisTime`|`uint64`|The genesis timestamp|
|`_epochsToAssumedFinality`|`uint64`|The number of epochs before an epoch is considered final on-chain|
|`_annualAprUpperBound`|`uint256`|The reporting upper bound|
|`_relativeLowerBound`|`uint256`|The reporting lower bound|


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


### getExpectedEpochId

Retrieve expected epoch id


```solidity
function getExpectedEpochId() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current expected epoch id|


### isValidEpoch

Verifies if the provided epoch is valid


```solidity
function isValidEpoch(uint256 _epoch) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_epoch`|`uint256`||

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
function setOracle(address _oracleAddress) external onlyAdmin_OMV1;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracleAddress`|`address`|Address of the oracle|


### setCLSpec

Set the consensus layer spec


```solidity
function setCLSpec(CLSpec.CLSpecStruct calldata _newValue) external onlyAdmin_OMV1;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`CLSpec.CLSpecStruct`|The new consensus layer spec value|


### setReportBounds

Set the report bounds


```solidity
function setReportBounds(ReportBounds.ReportBoundsStruct calldata _newValue) external onlyAdmin_OMV1;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`ReportBounds.ReportBoundsStruct`|The new report bounds value|


### setConsensusLayerData


```solidity
function setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport calldata _report) external virtual;
```

### _currentEpoch

Retrieve the current epoch based on the current timestamp


```solidity
function _currentEpoch(CLSpec.CLSpecStruct memory _cls) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_cls`|`CLSpec.CLSpecStruct`|The consensus layer spec struct|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current epoch|


### _isValidEpoch

Verifies if the given epoch is valid


```solidity
function _isValidEpoch(CLSpec.CLSpecStruct memory _cls, uint256 _epoch) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_cls`|`CLSpec.CLSpecStruct`|The consensus layer spec struct|
|`_epoch`|`uint256`|The epoch to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if valid|


### _maxIncrease

Retrieves the maximum increase in balance based on current total underlying supply and period since last report


```solidity
function _maxIncrease(ReportBounds.ReportBoundsStruct memory _rb, uint256 _prevTotalEth, uint256 _timeElapsed)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rb`|`ReportBounds.ReportBoundsStruct`|The report bounds struct|
|`_prevTotalEth`|`uint256`|The total underlying supply during reporting|
|`_timeElapsed`|`uint256`|The time since last report|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The maximum allowed increase in balance|


### _maxDecrease

Retrieves the maximum decrease in balance based on current total underlying supply


```solidity
function _maxDecrease(ReportBounds.ReportBoundsStruct memory _rb, uint256 _prevTotalEth)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rb`|`ReportBounds.ReportBoundsStruct`|The report bounds struct|
|`_prevTotalEth`|`uint256`|The total underlying supply during reporting|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The maximum allowed decrease in balance|


### _timeBetweenEpochs

Retrieve the number of seconds between two epochs


```solidity
function _timeBetweenEpochs(CLSpec.CLSpecStruct memory _cls, uint256 _epochPast, uint256 _epochNow)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_cls`|`CLSpec.CLSpecStruct`|The consensus layer spec struct|
|`_epochPast`|`uint256`|The starting epoch|
|`_epochNow`|`uint256`|The current epoch|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of seconds between the two epochs|


## Structs
### ConsensusLayerDataReportingVariables
Structure holding internal variables used during reporting


```solidity
struct ConsensusLayerDataReportingVariables {
    uint256 preReportUnderlyingBalance;
    uint256 postReportUnderlyingBalance;
    uint256 lastReportExitedBalance;
    uint256 lastReportSkimmedBalance;
    uint256 exitedAmountIncrease;
    uint256 skimmedAmountIncrease;
    uint256 timeElapsedSinceLastReport;
    uint256 availableAmountToUpperBound;
    uint256 redeemManagerDemand;
    ConsensusLayerDataReportingTrace trace;
}
```

