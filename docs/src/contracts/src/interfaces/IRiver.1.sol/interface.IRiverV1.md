# IRiverV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/IRiver.1.sol)

**Inherits:**
[IConsensusLayerDepositManagerV1](/contracts/src/interfaces/components/IConsensusLayerDepositManager.1.sol/interface.IConsensusLayerDepositManagerV1.md), [IUserDepositManagerV1](/contracts/src/interfaces/components/IUserDepositManager.1.sol/interface.IUserDepositManagerV1.md), [ISharesManagerV1](/contracts/src/interfaces/components/ISharesManager.1.sol/interface.ISharesManagerV1.md), [IOracleManagerV1](/contracts/src/interfaces/components/IOracleManager.1.sol/interface.IOracleManagerV1.md)

**Title:**
River Interface (v1)

**Author:**
Alluvial Finance Inc.

The main system interface


## Functions
### initRiverV1

Initializes the River system


```solidity
function initRiverV1(
    address _depositContractAddress,
    address _elFeeRecipientAddress,
    bytes32 _withdrawalCredentials,
    address _oracleAddress,
    address _systemAdministratorAddress,
    address _allowlistAddress,
    address _operatorRegistryAddress,
    address _collectorAddress,
    uint256 _globalFee
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_depositContractAddress`|`address`|Address to make Consensus Layer deposits|
|`_elFeeRecipientAddress`|`address`|Address that receives the execution layer fees|
|`_withdrawalCredentials`|`bytes32`|Credentials to use for every validator deposit|
|`_oracleAddress`|`address`|The address of the Oracle contract|
|`_systemAdministratorAddress`|`address`|Administrator address|
|`_allowlistAddress`|`address`|Address of the allowlist contract|
|`_operatorRegistryAddress`|`address`|Address of the operator registry|
|`_collectorAddress`|`address`|Address receiving the the global fee on revenue|
|`_globalFee`|`uint256`|Amount retained when the ETH balance increases and sent to the collector|


### initRiverV1_1

Initialized version 1.1 of the River System


```solidity
function initRiverV1_1(
    address _redeemManager,
    uint64 _epochsPerFrame,
    uint64 _slotsPerEpoch,
    uint64 _secondsPerSlot,
    uint64 _genesisTime,
    uint64 _epochsToAssumedFinality,
    uint256 _annualAprUpperBound,
    uint256 _relativeLowerBound,
    uint128 _maxDailyNetCommittableAmount_,
    uint128 _maxDailyRelativeCommittableAmount_
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemManager`|`address`|The redeem manager address|
|`_epochsPerFrame`|`uint64`|The amounts of epochs in a frame|
|`_slotsPerEpoch`|`uint64`|The slots inside an epoch|
|`_secondsPerSlot`|`uint64`|The seconds inside a slot|
|`_genesisTime`|`uint64`|The genesis timestamp|
|`_epochsToAssumedFinality`|`uint64`|The number of epochs before an epoch is considered final on-chain|
|`_annualAprUpperBound`|`uint256`|The reporting upper bound|
|`_relativeLowerBound`|`uint256`|The reporting lower bound|
|`_maxDailyNetCommittableAmount_`|`uint128`|The net daily committable limit|
|`_maxDailyRelativeCommittableAmount_`|`uint128`|The relative daily committable limit|


### initRiverV1_2

Initializes version 1.2 of the River System


```solidity
function initRiverV1_2() external;
```

### getGlobalFee

Get the current global fee


```solidity
function getGlobalFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The global fee|


### getAllowlist

Retrieve the allowlist address


```solidity
function getAllowlist() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The allowlist address|


### getCollector

Retrieve the collector address


```solidity
function getCollector() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The collector address|


### getELFeeRecipient

Retrieve the execution layer fee recipient


```solidity
function getELFeeRecipient() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The execution layer fee recipient address|


### getCoverageFund

Retrieve the coverage fund


```solidity
function getCoverageFund() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The coverage fund address|


### getRedeemManager

Retrieve the redeem manager


```solidity
function getRedeemManager() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The redeem manager address|


### getOperatorsRegistry

Retrieve the operators registry


```solidity
function getOperatorsRegistry() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The operators registry address|


### getMetadataURI

Retrieve the metadata uri string value


```solidity
function getMetadataURI() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The metadata uri string value|


### getDailyCommittableLimits

Retrieve the configured daily committable limits


```solidity
function getDailyCommittableLimits()
    external
    view
    returns (DailyCommittableLimits.DailyCommittableLimitsStruct memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`DailyCommittableLimits.DailyCommittableLimitsStruct`|The daily committable limits structure|


### resolveRedeemRequests

Resolves the provided redeem requests by calling the redeem manager


```solidity
function resolveRedeemRequests(uint32[] calldata _redeemRequestIds)
    external
    view
    returns (int64[] memory withdrawalEventIds);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequestIds`|`uint32[]`|The list of redeem requests to resolve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`withdrawalEventIds`|`int64[]`|The list of matching withdrawal events, or error codes|


### setDailyCommittableLimits

Set the daily committable limits


```solidity
function setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct memory _dcl) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dcl`|`DailyCommittableLimits.DailyCommittableLimitsStruct`|The Daily Committable Limits structure|


### getBalanceToRedeem

Retrieve the current balance to redeem


```solidity
function getBalanceToRedeem() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current balance to redeem|


### requestRedeem

Performs a redeem request on the redeem manager


```solidity
function requestRedeem(uint256 _lsETHAmount, address _recipient) external returns (uint32 redeemRequestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lsETHAmount`|`uint256`|The amount of LsETH to redeem|
|`_recipient`|`address`|The address that will own the redeem request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`redeemRequestId`|`uint32`|The ID of the newly created redeem request|


### claimRedeemRequests

Claims several redeem requests


```solidity
function claimRedeemRequests(uint32[] calldata _redeemRequestIds, uint32[] calldata _withdrawalEventIds)
    external
    returns (uint8[] memory claimStatuses);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequestIds`|`uint32[]`|The list of redeem requests to claim|
|`_withdrawalEventIds`|`uint32[]`|The list of resolved withdrawal event ids|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`claimStatuses`|`uint8[]`|The operation status results|


### setGlobalFee

Changes the global fee parameter


```solidity
function setGlobalFee(uint256 _newFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newFee`|`uint256`|New fee value|


### setAllowlist

Changes the allowlist address


```solidity
function setAllowlist(address _newAllowlist) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newAllowlist`|`address`|New address for the allowlist|


### setCollector

Changes the collector address


```solidity
function setCollector(address _newCollector) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newCollector`|`address`|New address for the collector|


### setELFeeRecipient

Changes the execution layer fee recipient


```solidity
function setELFeeRecipient(address _newELFeeRecipient) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newELFeeRecipient`|`address`|New address for the recipient|


### setCoverageFund

Changes the coverage fund


```solidity
function setCoverageFund(address _newCoverageFund) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newCoverageFund`|`address`|New address for the fund|


### setMetadataURI

Sets the metadata uri string value


```solidity
function setMetadataURI(string memory _metadataURI) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_metadataURI`|`string`|The new metadata uri string value|


### sendELFees

Input for execution layer fee earnings


```solidity
function sendELFees() external payable;
```

### sendCLFunds

Input for consensus layer funds, containing both exit and skimming


```solidity
function sendCLFunds() external payable;
```

### sendCoverageFunds

Input for coverage funds


```solidity
function sendCoverageFunds() external payable;
```

### sendRedeemManagerExceedingFunds

Input for the redeem manager funds


```solidity
function sendRedeemManagerExceedingFunds() external payable;
```

## Events
### PulledELFees
Funds have been pulled from the Execution Layer Fee Recipient


```solidity
event PulledELFees(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount pulled|

### PulledCoverageFunds
Funds have been pulled from the Coverage Fund


```solidity
event PulledCoverageFunds(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount pulled|

### PulledRedeemManagerExceedingEth
Emitted when funds are pulled from the redeem manager


```solidity
event PulledRedeemManagerExceedingEth(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount pulled|

### PulledCLFunds
Emitted when funds are pulled from the CL recipient


```solidity
event PulledCLFunds(uint256 pulledSkimmedEthAmount, uint256 pullExitedEthAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pulledSkimmedEthAmount`|`uint256`|The amount of skimmed ETH pulled|
|`pullExitedEthAmount`|`uint256`|The amount of exited ETH pulled|

### SetELFeeRecipient
The stored Execution Layer Fee Recipient has been changed


```solidity
event SetELFeeRecipient(address indexed elFeeRecipient);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`elFeeRecipient`|`address`|The new Execution Layer Fee Recipient|

### SetCoverageFund
The stored Coverage Fund has been changed


```solidity
event SetCoverageFund(address indexed coverageFund);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`coverageFund`|`address`|The new Coverage Fund|

### SetCollector
The stored Collector has been changed


```solidity
event SetCollector(address indexed collector);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collector`|`address`|The new Collector|

### SetAllowlist
The stored Allowlist has been changed


```solidity
event SetAllowlist(address indexed allowlist);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`allowlist`|`address`|The new Allowlist|

### SetGlobalFee
The stored Global Fee has been changed


```solidity
event SetGlobalFee(uint256 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|The new Global Fee|

### SetOperatorsRegistry
The stored Operators Registry has been changed


```solidity
event SetOperatorsRegistry(address indexed operatorRegistry);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operatorRegistry`|`address`|The new Operators Registry|

### SetMetadataURI
The stored Metadata URI string has been changed


```solidity
event SetMetadataURI(string metadataURI);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`metadataURI`|`string`|The new Metadata URI string|

### RewardsEarned
The system underlying supply increased. This is a snapshot of the balances for accounting purposes


```solidity
event RewardsEarned(
    address indexed _collector,
    uint256 _oldTotalUnderlyingBalance,
    uint256 _oldTotalSupply,
    uint256 _newTotalUnderlyingBalance,
    uint256 _newTotalSupply
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collector`|`address`|The address of the collector during this event|
|`_oldTotalUnderlyingBalance`|`uint256`|Old total ETH balance under management by River|
|`_oldTotalSupply`|`uint256`|Old total supply in shares|
|`_newTotalUnderlyingBalance`|`uint256`|New total ETH balance under management by River|
|`_newTotalSupply`|`uint256`|New total supply in shares|

### SetMaxDailyCommittableAmounts
Emitted when the daily committable limits are changed


```solidity
event SetMaxDailyCommittableAmounts(uint256 minNetAmount, uint256 maxRelativeAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minNetAmount`|`uint256`|The minimum amount that must be used as the daily committable amount|
|`maxRelativeAmount`|`uint256`|The maximum amount that can be used as the daily committable amount, relative to the total underlying supply|

### SetRedeemManager
Emitted when the redeem manager address is changed


```solidity
event SetRedeemManager(address redeemManager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemManager`|`address`|The address of the redeem manager|

### SetBalanceToDeposit
Emitted when the balance to deposit is updated


```solidity
event SetBalanceToDeposit(uint256 oldAmount, uint256 newAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAmount`|`uint256`|The old balance to deposit|
|`newAmount`|`uint256`|The new balance to deposit|

### SetBalanceToRedeem
Emitted when the balance to redeem is updated


```solidity
event SetBalanceToRedeem(uint256 oldAmount, uint256 newAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAmount`|`uint256`|The old balance to redeem|
|`newAmount`|`uint256`|The new balance to redeem|

### SetBalanceCommittedToDeposit
Emitted when the balance committed to deposit


```solidity
event SetBalanceCommittedToDeposit(uint256 oldAmount, uint256 newAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAmount`|`uint256`|The old balance committed to deposit|
|`newAmount`|`uint256`|The new balance committed to deposit|

### ReportedRedeemManager
Emitted when the redeem manager received a withdraw event report


```solidity
event ReportedRedeemManager(
    uint256 redeemManagerDemand, uint256 suppliedRedeemManagerDemand, uint256 suppliedRedeemManagerDemandInEth
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemManagerDemand`|`uint256`|The total demand in LsETH of the redeem manager|
|`suppliedRedeemManagerDemand`|`uint256`|The amount of LsETH demand actually supplied|
|`suppliedRedeemManagerDemandInEth`|`uint256`|The amount in ETH of the supplied demand|

## Errors
### InvalidPulledClFundsAmount
Thrown when the amount received from the Withdraw contract doe not match the requested amount


```solidity
error InvalidPulledClFundsAmount(uint256 requested, uint256 received);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requested`|`uint256`|The amount that was requested|
|`received`|`uint256`|The amount that was received|

### ZeroMintedShares
The computed amount of shares to mint is 0


```solidity
error ZeroMintedShares();
```

### Denied
The access was denied


```solidity
error Denied(address account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account that was denied|

