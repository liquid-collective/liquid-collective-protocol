# RiverV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/River.1.sol)

**Inherits:**
[ConsensusLayerDepositManagerV1](/contracts/src/components/ConsensusLayerDepositManager.1.sol/abstract.ConsensusLayerDepositManagerV1.md), [UserDepositManagerV1](/contracts/src/components/UserDepositManager.1.sol/abstract.UserDepositManagerV1.md), [SharesManagerV1](/contracts/src/components/SharesManager.1.sol/abstract.SharesManagerV1.md), [OracleManagerV1](/contracts/src/components/OracleManager.1.sol/abstract.OracleManagerV1.md), [Initializable](/contracts/src/Initializable.sol/contract.Initializable.md), [Administrable](/contracts/src/Administrable.sol/abstract.Administrable.md), [IProtocolVersion](/contracts/src/interfaces/IProtocolVersion.sol/interface.IProtocolVersion.md), [IRiverV1](/contracts/src/interfaces/IRiver.1.sol/interface.IRiverV1.md)

**Title:**
River (v1)

**Author:**
Alluvial Finance Inc.

This contract merges all the manager contracts and implements all the virtual methods stitching all components together


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
) external init(0);
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
    uint128 _minDailyNetCommittableAmount_,
    uint128 _maxDailyRelativeCommittableAmount_
) external init(1);
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
|`_minDailyNetCommittableAmount_`|`uint128`||
|`_maxDailyRelativeCommittableAmount_`|`uint128`|The relative daily committable limit|


### initRiverV1_2

Initializes version 1.2 of the River System


```solidity
function initRiverV1_2() external init(2);
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


### setDailyCommittableLimits

Set the daily committable limits


```solidity
function setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct memory _dcl)
    external
    onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dcl`|`DailyCommittableLimits.DailyCommittableLimitsStruct`|The Daily Committable Limits structure|


### setKeeper


```solidity
function setKeeper(address _keeper) external onlyAdmin;
```

### getBalanceToRedeem

Retrieve the current balance to redeem


```solidity
function getBalanceToRedeem() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current balance to redeem|


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


### requestRedeem

Performs a redeem request on the redeem manager


```solidity
function requestRedeem(uint256 _lsETHAmount, address _recipient) external returns (uint32 _redeemRequestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lsETHAmount`|`uint256`|The amount of LsETH to redeem|
|`_recipient`|`address`|The address that will own the redeem request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequestId`|`uint32`|redeemRequestId The ID of the newly created redeem request|


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
function setGlobalFee(uint256 _newFee) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newFee`|`uint256`|New fee value|


### setAllowlist

Changes the allowlist address


```solidity
function setAllowlist(address _newAllowlist) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newAllowlist`|`address`|New address for the allowlist|


### setCollector

Changes the collector address


```solidity
function setCollector(address _newCollector) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newCollector`|`address`|New address for the collector|


### setELFeeRecipient

Changes the execution layer fee recipient


```solidity
function setELFeeRecipient(address _newELFeeRecipient) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newELFeeRecipient`|`address`|New address for the recipient|


### setCoverageFund

Changes the coverage fund


```solidity
function setCoverageFund(address _newCoverageFund) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newCoverageFund`|`address`|New address for the fund|


### setMetadataURI

Sets the metadata uri string value


```solidity
function setMetadataURI(string memory _metadataURI) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_metadataURI`|`string`|The new metadata uri string value|


### getOperatorsRegistry

Retrieve the operators registry


```solidity
function getOperatorsRegistry() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The operators registry address|


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

### _getRiverAdmin

Overridden handler to pass the system admin inside components


```solidity
function _getRiverAdmin()
    internal
    view
    override(OracleManagerV1, ConsensusLayerDepositManagerV1)
    returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the admin|


### _onTransfer

Overridden handler called whenever a token transfer is triggered


```solidity
function _onTransfer(address _from, address _to) internal view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Token sender|
|`_to`|`address`|Token receiver|


### _onDeposit

Overridden handler called whenever a user deposits ETH to the system. Mints the adequate amount of shares.


```solidity
function _onDeposit(address _depositor, address _recipient, uint256 _amount) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_depositor`|`address`|User address that made the deposit|
|`_recipient`|`address`||
|`_amount`|`uint256`|Amount of ETH deposited|


### _getNextValidators

Overridden handler called whenever a deposit to the consensus layer is made based on node operator allocations.


```solidity
function _getNextValidators(IOperatorsRegistryV1.OperatorAllocation[] memory _allocations)
    internal
    override
    returns (bytes[] memory publicKeys, bytes[] memory signatures);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_allocations`|`IOperatorsRegistryV1.OperatorAllocation[]`|Node operator allocations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKeys`|`bytes[]`|Array of fundable public keys|
|`signatures`|`bytes[]`|Array of signatures linked to the public keys|


### _pullELFees

Overridden handler to pull funds from the execution layer fee recipient to River and return the delta in the balance


```solidity
function _pullELFees(uint256 _max) internal override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_max`|`uint256`|The maximum amount to pull from the execution layer fee recipient|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount pulled from the execution layer fee recipient|


### _pullCoverageFunds

Overridden handler to pull funds from the coverage fund to River and return the delta in the balance


```solidity
function _pullCoverageFunds(uint256 _max) internal override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_max`|`uint256`|The maximum amount to pull from the coverage fund|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount pulled from the coverage fund|


### _onEarnings

Overridden handler called whenever the balance of ETH handled by the system increases. Computes the fees paid to the collector


```solidity
function _onEarnings(uint256 _amount) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|Additional ETH received|


### _assetBalance

Overridden handler called whenever the total balance of ETH is requested


```solidity
function _assetBalance() internal view override(SharesManagerV1, OracleManagerV1) returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current total asset balance managed by River|


### _setDailyCommittableLimits

Internal utility to set the daily committable limits


```solidity
function _setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct memory _dcl) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dcl`|`DailyCommittableLimits.DailyCommittableLimitsStruct`|The new daily committable limits|


### _setBalanceToDeposit

Sets the balance to deposit, but not yet committed


```solidity
function _setBalanceToDeposit(uint256 _newBalanceToDeposit) internal override(UserDepositManagerV1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newBalanceToDeposit`|`uint256`|The new balance to deposit value|


### _setBalanceToRedeem

Sets the balance to redeem, to be used to satisfy redeem requests on the redeem manager


```solidity
function _setBalanceToRedeem(uint256 _newBalanceToRedeem) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newBalanceToRedeem`|`uint256`|The new balance to redeem value|


### _setCommittedBalance

Sets the committed balance, ready to be deposited to the consensus layer


```solidity
function _setCommittedBalance(uint256 _newCommittedBalance) internal override(ConsensusLayerDepositManagerV1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newCommittedBalance`|`uint256`|The new committed balance value|


### _pullCLFunds

Pulls funds from the Withdraw contract, and adds funds to deposit and redeem balances


```solidity
function _pullCLFunds(uint256 _skimmedEthAmount, uint256 _exitedEthAmount) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_skimmedEthAmount`|`uint256`|The new amount of skimmed eth to pull|
|`_exitedEthAmount`|`uint256`|The new amount of exited eth to pull|


### _pullRedeemManagerExceedingEth

Pulls funds from the redeem manager exceeding eth buffer


```solidity
function _pullRedeemManagerExceedingEth(uint256 _max) internal override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_max`|`uint256`|The maximum amount to pull|


### _reportWithdrawToRedeemManager

Use the balance to redeem to report a withdrawal event on the redeem manager


```solidity
function _reportWithdrawToRedeemManager() internal override;
```

### _requestExitsBasedOnRedeemDemandAfterRebalancings

Requests exits of validators after possibly rebalancing deposit and redeem balances


```solidity
function _requestExitsBasedOnRedeemDemandAfterRebalancings(
    uint256 _exitingBalance,
    uint32[] memory _stoppedValidatorCounts,
    bool _depositToRedeemRebalancingAllowed,
    bool _slashingContainmentModeEnabled
) internal override;
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
function _skimExcessBalanceToRedeem() internal override;
```

### _commitBalanceToDeposit

Commits the deposit balance up to the allowed daily limit in batches of 32 ETH.

Committed funds are funds waiting to be deposited but that cannot be used to fund the redeem manager anymore

This two step process is required to prevent possible out of gas issues we would have from actually funding the validators at this point


```solidity
function _commitBalanceToDeposit(uint256 _period) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_period`|`uint256`|The period between current and last report|


### version


```solidity
function version() external pure returns (string memory);
```

