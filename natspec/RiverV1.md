# RiverV1

*Alluvial Finance Inc.*

> River (v1)

This contract merges all the manager contracts and implements all the virtual methods stitching all components together



## Methods

### DEPOSIT_SIZE

```solidity
function DEPOSIT_SIZE() external view returns (uint256)
```

Size of a deposit in ETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### PUBLIC_KEY_LENGTH

```solidity
function PUBLIC_KEY_LENGTH() external view returns (uint256)
```

Size of a BLS Public key in bytes




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### SIGNATURE_LENGTH

```solidity
function SIGNATURE_LENGTH() external view returns (uint256)
```

Size of a BLS Signature in bytes




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### _DEPOSIT_SIZE

```solidity
function _DEPOSIT_SIZE() external view returns (uint256)
```

Size of a deposit in ETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### acceptAdmin

```solidity
function acceptAdmin() external nonpayable
```

Accept the transfer of ownership

*Only callable by the pending admin. Resets the pending admin if succesful.*


### allowance

```solidity
function allowance(address _owner, address _spender) external view returns (uint256)
```

Retrieve the allowance value for a spender



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Address that issued the allowance |
| _spender | address | Address that received the allowance |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The allowance in shares for a given spender |

### approve

```solidity
function approve(address _spender, uint256 _value) external nonpayable returns (bool)
```

Approves an account for future spendings

*An approved account can use transferFrom to transfer funds on behalf of the token owner*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | Address that is allowed to spend the tokens |
| _value | uint256 | The allowed amount in shares, will override previous value |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

### balanceOf

```solidity
function balanceOf(address _owner) external view returns (uint256)
```

Retrieve the balance of an account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Address to be checked |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The balance of the account in shares |

### balanceOfUnderlying

```solidity
function balanceOfUnderlying(address _owner) external view returns (uint256)
```

Retrieve the underlying asset balance of an account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Address to be checked |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The underlying balance of the account |

### claimRedeemRequests

```solidity
function claimRedeemRequests(uint32[] _redeemRequestIds, uint32[] _withdrawalEventIds) external nonpayable returns (uint8[] claimStatuses)
```

Claims several redeem requests



#### Parameters

| Name | Type | Description |
|---|---|---|
| _redeemRequestIds | uint32[] | The list of redeem requests to claim |
| _withdrawalEventIds | uint32[] | The list of resolved withdrawal event ids |

#### Returns

| Name | Type | Description |
|---|---|---|
| claimStatuses | uint8[] | The operation status results |

### decimals

```solidity
function decimals() external pure returns (uint8)
```

Retrieve the decimal count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | The decimal count |

### decreaseAllowance

```solidity
function decreaseAllowance(address _spender, uint256 _subtractableValue) external nonpayable returns (bool)
```

Decrease allowance to another account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | Spender that receives the allowance |
| _subtractableValue | uint256 | Amount of shares to subtract |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

### deposit

```solidity
function deposit() external payable
```

Explicit deposit method to mint on msg.sender




### depositAndTransfer

```solidity
function depositAndTransfer(address _recipient) external payable
```

Explicit deposit method to mint on msg.sender and transfer to _recipient



#### Parameters

| Name | Type | Description |
|---|---|---|
| _recipient | address | Address receiving the minted LsETH |

### depositToConsensusLayerWithDepositRoot

```solidity
function depositToConsensusLayerWithDepositRoot(uint256 _maxCount, bytes32 _depositRoot) external nonpayable
```

Deposits current balance to the Consensus Layer by batches of 32 ETH



#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxCount | uint256 | The maximum amount of validator keys to fund |
| _depositRoot | bytes32 | The root of the deposit tree |

### getAdmin

```solidity
function getAdmin() external view returns (address)
```

Retrieves the current admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The admin address |

### getAllowlist

```solidity
function getAllowlist() external view returns (address)
```

Retrieve the allowlist address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The allowlist address |

### getBalanceToDeposit

```solidity
function getBalanceToDeposit() external view returns (uint256)
```

Returns the amount of ETH not yet committed for deposit




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of ETH not yet committed for deposit |

### getBalanceToRedeem

```solidity
function getBalanceToRedeem() external view returns (uint256)
```

Retrieve the current balance to redeem




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current balance to redeem |

### getCLSpec

```solidity
function getCLSpec() external view returns (struct CLSpec.CLSpecStruct)
```

Retrieve the current cl spec




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | CLSpec.CLSpecStruct | The Consensus Layer Specification |

### getCLValidatorCount

```solidity
function getCLValidatorCount() external view returns (uint256)
```

Get CL validator count (the amount of validator reported by the oracles)




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The CL validator count |

### getCLValidatorTotalBalance

```solidity
function getCLValidatorTotalBalance() external view returns (uint256)
```

Get CL validator total balance




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The CL Validator total balance |

### getCollector

```solidity
function getCollector() external view returns (address)
```

Retrieve the collector address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The collector address |

### getCommittedBalance

```solidity
function getCommittedBalance() external view returns (uint256)
```

Returns the amount of ETH committed for deposit




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of ETH committed for deposit |

### getCoverageFund

```solidity
function getCoverageFund() external view returns (address)
```

Retrieve the coverage fund




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The coverage fund address |

### getCurrentEpochId

```solidity
function getCurrentEpochId() external view returns (uint256)
```

Retrieve the current epoch id based on block timestamp




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current epoch id |

### getCurrentFrame

```solidity
function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime)
```

Retrieve the current frame details




#### Returns

| Name | Type | Description |
|---|---|---|
| _startEpochId | uint256 | The epoch at the beginning of the frame |
| _startTime | uint256 | The timestamp of the beginning of the frame in seconds |
| _endTime | uint256 | The timestamp of the end of the frame in seconds |

### getDailyCommittableLimits

```solidity
function getDailyCommittableLimits() external view returns (struct DailyCommittableLimits.DailyCommittableLimitsStruct)
```

Retrieve the configured daily committable limits




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | DailyCommittableLimits.DailyCommittableLimitsStruct | The daily committable limits structure |

### getDepositedValidatorCount

```solidity
function getDepositedValidatorCount() external view returns (uint256)
```

Get the deposited validator count (the count of deposits made by the contract)




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The deposited validator count |

### getELFeeRecipient

```solidity
function getELFeeRecipient() external view returns (address)
```

Retrieve the execution layer fee recipient




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The execution layer fee recipient address |

### getExpectedEpochId

```solidity
function getExpectedEpochId() external view returns (uint256)
```

Retrieve expected epoch id




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current expected epoch id |

### getFrameFirstEpochId

```solidity
function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256)
```

Retrieve the first epoch id of the frame of the provided epoch id



#### Parameters

| Name | Type | Description |
|---|---|---|
| _epochId | uint256 | Epoch id used to get the frame |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The first epoch id of the frame containing the given epoch id |

### getGlobalFee

```solidity
function getGlobalFee() external view returns (uint256)
```

Get the current global fee




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The global fee |

### getKeeper

```solidity
function getKeeper() external view returns (address)
```

Get the keeper address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The keeper address |

### getLastCompletedEpochId

```solidity
function getLastCompletedEpochId() external view returns (uint256)
```

Retrieve the last completed epoch id




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The last completed epoch id |

### getLastConsensusLayerReport

```solidity
function getLastConsensusLayerReport() external view returns (struct IOracleManagerV1.StoredConsensusLayerReport)
```

Retrieve the last consensus layer report




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | IOracleManagerV1.StoredConsensusLayerReport | The stored consensus layer report |

### getMetadataURI

```solidity
function getMetadataURI() external view returns (string)
```

Retrieve the metadata uri string value




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | The metadata uri string value |

### getOperatorsRegistry

```solidity
function getOperatorsRegistry() external view returns (address)
```

Retrieve the operators registry




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The operators registry address |

### getOracle

```solidity
function getOracle() external view returns (address)
```

Get oracle address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The oracle address |

### getPendingAdmin

```solidity
function getPendingAdmin() external view returns (address)
```

Retrieve the current pending admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The pending admin address |

### getRedeemManager

```solidity
function getRedeemManager() external view returns (address)
```

Retrieve the redeem manager




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The redeem manager address |

### getReportBounds

```solidity
function getReportBounds() external view returns (struct ReportBounds.ReportBoundsStruct)
```

Retrieve the report bounds




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | ReportBounds.ReportBoundsStruct | The report bounds |

### getTime

```solidity
function getTime() external view returns (uint256)
```

Retrieve the block timestamp




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The current timestamp from the EVM context |

### getWithdrawalCredentials

```solidity
function getWithdrawalCredentials() external view returns (bytes32)
```

Retrieve the withdrawal credentials




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | The withdrawal credentials |

### increaseAllowance

```solidity
function increaseAllowance(address _spender, uint256 _additionalValue) external nonpayable returns (bool)
```

Increase allowance to another account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | Spender that receives the allowance |
| _additionalValue | uint256 | Amount of shares to add |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

### initRiverV1

```solidity
function initRiverV1(address _depositContractAddress, address _elFeeRecipientAddress, bytes32 _withdrawalCredentials, address _oracleAddress, address _systemAdministratorAddress, address _allowlistAddress, address _operatorRegistryAddress, address _collectorAddress, uint256 _globalFee) external nonpayable
```

Initializes the River system



#### Parameters

| Name | Type | Description |
|---|---|---|
| _depositContractAddress | address | Address to make Consensus Layer deposits |
| _elFeeRecipientAddress | address | Address that receives the execution layer fees |
| _withdrawalCredentials | bytes32 | Credentials to use for every validator deposit |
| _oracleAddress | address | The address of the Oracle contract |
| _systemAdministratorAddress | address | Administrator address |
| _allowlistAddress | address | Address of the allowlist contract |
| _operatorRegistryAddress | address | Address of the operator registry |
| _collectorAddress | address | Address receiving the the global fee on revenue |
| _globalFee | uint256 | Amount retained when the ETH balance increases and sent to the collector |

### initRiverV1_1

```solidity
function initRiverV1_1(address _redeemManager, uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime, uint64 _epochsToAssumedFinality, uint256 _annualAprUpperBound, uint256 _relativeLowerBound, uint128 _minDailyNetCommittableAmount_, uint128 _maxDailyRelativeCommittableAmount_) external nonpayable
```

Initialized version 1.1 of the River System



#### Parameters

| Name | Type | Description |
|---|---|---|
| _redeemManager | address | The redeem manager address |
| _epochsPerFrame | uint64 | The amounts of epochs in a frame |
| _slotsPerEpoch | uint64 | The slots inside an epoch |
| _secondsPerSlot | uint64 | The seconds inside a slot |
| _genesisTime | uint64 | The genesis timestamp |
| _epochsToAssumedFinality | uint64 | The number of epochs before an epoch is considered final on-chain |
| _annualAprUpperBound | uint256 | The reporting upper bound |
| _relativeLowerBound | uint256 | The reporting lower bound |
| _minDailyNetCommittableAmount_ | uint128 | undefined |
| _maxDailyRelativeCommittableAmount_ | uint128 | The relative daily committable limit |

### initRiverV1_2

```solidity
function initRiverV1_2() external nonpayable
```

Initializes version 1.2 of the River System




### isValidEpoch

```solidity
function isValidEpoch(uint256 _epoch) external view returns (bool)
```

Verifies if the provided epoch is valid



#### Parameters

| Name | Type | Description |
|---|---|---|
| _epoch | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if valid |

### name

```solidity
function name() external pure returns (string)
```

Retrieve the token name




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | The token name |

### proposeAdmin

```solidity
function proposeAdmin(address _newAdmin) external nonpayable
```

Proposes a new address as admin

*This security prevents setting an invalid address as an admin. The pendingadmin has to claim its ownership of the contract, and prove that the newaddress is able to perform regular transactions.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | New admin address |

### requestRedeem

```solidity
function requestRedeem(uint256 _lsETHAmount, address _recipient) external nonpayable returns (uint32 _redeemRequestId)
```

Performs a redeem request on the redeem manager



#### Parameters

| Name | Type | Description |
|---|---|---|
| _lsETHAmount | uint256 | The amount of LsETH to redeem |
| _recipient | address | The address that will own the redeem request |

#### Returns

| Name | Type | Description |
|---|---|---|
| _redeemRequestId | uint32 | The ID of the newly created redeem request |

### resolveRedeemRequests

```solidity
function resolveRedeemRequests(uint32[] _redeemRequestIds) external view returns (int64[] withdrawalEventIds)
```

Resolves the provided redeem requests by calling the redeem manager



#### Parameters

| Name | Type | Description |
|---|---|---|
| _redeemRequestIds | uint32[] | The list of redeem requests to resolve |

#### Returns

| Name | Type | Description |
|---|---|---|
| withdrawalEventIds | int64[] | The list of matching withdrawal events, or error codes |

### sendCLFunds

```solidity
function sendCLFunds() external payable
```

Input for consensus layer funds, containing both exit and skimming




### sendCoverageFunds

```solidity
function sendCoverageFunds() external payable
```

Input for coverage funds




### sendELFees

```solidity
function sendELFees() external payable
```

Input for execution layer fee earnings




### sendRedeemManagerExceedingFunds

```solidity
function sendRedeemManagerExceedingFunds() external payable
```

Input for the redeem manager funds




### setAllowlist

```solidity
function setAllowlist(address _newAllowlist) external nonpayable
```

Changes the allowlist address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAllowlist | address | New address for the allowlist |

### setCLSpec

```solidity
function setCLSpec(CLSpec.CLSpecStruct _newValue) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newValue | CLSpec.CLSpecStruct | undefined |

### setCollector

```solidity
function setCollector(address _newCollector) external nonpayable
```

Changes the collector address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newCollector | address | New address for the collector |

### setConsensusLayerData

```solidity
function setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport _report) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _report | IOracleManagerV1.ConsensusLayerReport | undefined |

### setCoverageFund

```solidity
function setCoverageFund(address _newCoverageFund) external nonpayable
```

Changes the coverage fund



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newCoverageFund | address | New address for the fund |

### setDailyCommittableLimits

```solidity
function setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct _dcl) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dcl | DailyCommittableLimits.DailyCommittableLimitsStruct | undefined |

### setELFeeRecipient

```solidity
function setELFeeRecipient(address _newELFeeRecipient) external nonpayable
```

Changes the execution layer fee recipient



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newELFeeRecipient | address | New address for the recipient |

### setGlobalFee

```solidity
function setGlobalFee(uint256 _newFee) external nonpayable
```

Changes the global fee parameter



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newFee | uint256 | New fee value |

### setKeeper

```solidity
function setKeeper(address _keeper) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _keeper | address | undefined |

### setMetadataURI

```solidity
function setMetadataURI(string _metadataURI) external nonpayable
```

Sets the metadata uri string value



#### Parameters

| Name | Type | Description |
|---|---|---|
| _metadataURI | string | The new metadata uri string value |

### setOracle

```solidity
function setOracle(address _oracleAddress) external nonpayable
```

Set the oracle address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleAddress | address | Address of the oracle |

### setReportBounds

```solidity
function setReportBounds(ReportBounds.ReportBoundsStruct _newValue) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newValue | ReportBounds.ReportBoundsStruct | undefined |

### sharesFromUnderlyingBalance

```solidity
function sharesFromUnderlyingBalance(uint256 _underlyingAssetAmount) external view returns (uint256)
```

Retrieve the shares count from an underlying asset amount



#### Parameters

| Name | Type | Description |
|---|---|---|
| _underlyingAssetAmount | uint256 | Amount of underlying asset to convert |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of shares worth the underlying asset amopunt |

### symbol

```solidity
function symbol() external pure returns (string)
```

Retrieve the token symbol




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | The token symbol |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```

Retrieve the total token supply




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The total supply in shares |

### totalUnderlyingSupply

```solidity
function totalUnderlyingSupply() external view returns (uint256)
```

Retrieve the total underlying asset supply




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The total underlying asset supply |

### transfer

```solidity
function transfer(address _to, uint256 _value) external nonpayable returns (bool)
```

Performs a transfer from the message sender to the provided account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _to | address | Address receiving the tokens |
| _value | uint256 | Amount of shares to be sent |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

### transferFrom

```solidity
function transferFrom(address _from, address _to, uint256 _value) external nonpayable returns (bool)
```

Performs a transfer between two recipients



#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | Address sending the tokens |
| _to | address | Address receiving the tokens |
| _value | uint256 | Amount of shares to be sent |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

### underlyingBalanceFromShares

```solidity
function underlyingBalanceFromShares(uint256 _shares) external view returns (uint256)
```

Retrieve the underlying asset balance from an amount of shares



#### Parameters

| Name | Type | Description |
|---|---|---|
| _shares | uint256 | Amount of shares to convert |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The underlying asset balance represented by the shares |

### version

```solidity
function version() external pure returns (string)
```

Retrieves the version of the contract




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | Version of the contract |



## Events

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```



*Emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}. `value` is the new allowance.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| value  | uint256 | undefined |

### ConsensusLayerDataUpdate

```solidity
event ConsensusLayerDataUpdate(uint256 validatorCount, uint256 validatorTotalBalance, bytes32 roundId)
```

The consensus layer data provided by the oracle has been updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| validatorCount  | uint256 | The new count of validators running on the consensus layer |
| validatorTotalBalance  | uint256 | The new total balance sum of all validators |
| roundId  | bytes32 | Round identifier |

### Initialize

```solidity
event Initialize(uint256 version, bytes cdata)
```

Emitted when the contract is properly initialized



#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint256 | New version of the contracts |
| cdata  | bytes | Complete calldata that was used during the initialization |

### ProcessedConsensusLayerReport

```solidity
event ProcessedConsensusLayerReport(IOracleManagerV1.ConsensusLayerReport report, IOracleManagerV1.ConsensusLayerDataReportingTrace trace)
```

The provided report has beend processed



#### Parameters

| Name | Type | Description |
|---|---|---|
| report  | IOracleManagerV1.ConsensusLayerReport | The report that was provided |
| trace  | IOracleManagerV1.ConsensusLayerDataReportingTrace | The trace structure providing more insights on internals |

### PulledCLFunds

```solidity
event PulledCLFunds(uint256 pulledSkimmedEthAmount, uint256 pullExitedEthAmount)
```

Emitted when funds are pulled from the CL recipient



#### Parameters

| Name | Type | Description |
|---|---|---|
| pulledSkimmedEthAmount  | uint256 | The amount of skimmed ETH pulled |
| pullExitedEthAmount  | uint256 | The amount of exited ETH pulled |

### PulledCoverageFunds

```solidity
event PulledCoverageFunds(uint256 amount)
```

Funds have been pulled from the Coverage Fund



#### Parameters

| Name | Type | Description |
|---|---|---|
| amount  | uint256 | The amount pulled |

### PulledELFees

```solidity
event PulledELFees(uint256 amount)
```

Funds have been pulled from the Execution Layer Fee Recipient



#### Parameters

| Name | Type | Description |
|---|---|---|
| amount  | uint256 | The amount pulled |

### PulledRedeemManagerExceedingEth

```solidity
event PulledRedeemManagerExceedingEth(uint256 amount)
```

Emitted when funds are pulled from the redeem manager



#### Parameters

| Name | Type | Description |
|---|---|---|
| amount  | uint256 | The amount pulled |

### ReportedRedeemManager

```solidity
event ReportedRedeemManager(uint256 redeemManagerDemand, uint256 suppliedRedeemManagerDemand, uint256 suppliedRedeemManagerDemandInEth)
```

Emitted when the redeem manager received a withdraw event report



#### Parameters

| Name | Type | Description |
|---|---|---|
| redeemManagerDemand  | uint256 | The total demand in LsETH of the redeem manager |
| suppliedRedeemManagerDemand  | uint256 | The amount of LsETH demand actually supplied |
| suppliedRedeemManagerDemandInEth  | uint256 | The amount in ETH of the supplied demand |

### RewardsEarned

```solidity
event RewardsEarned(address indexed _collector, uint256 _oldTotalUnderlyingBalance, uint256 _oldTotalSupply, uint256 _newTotalUnderlyingBalance, uint256 _newTotalSupply)
```

The system underlying supply increased. This is a snapshot of the balances for accounting purposes



#### Parameters

| Name | Type | Description |
|---|---|---|
| _collector `indexed` | address | The address of the collector during this event |
| _oldTotalUnderlyingBalance  | uint256 | Old total ETH balance under management by River |
| _oldTotalSupply  | uint256 | Old total supply in shares |
| _newTotalUnderlyingBalance  | uint256 | New total ETH balance under management by River |
| _newTotalSupply  | uint256 | New total supply in shares |

### SetAdmin

```solidity
event SetAdmin(address indexed admin)
```

The admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| admin `indexed` | address | New admin address |

### SetAllowlist

```solidity
event SetAllowlist(address indexed allowlist)
```

The stored Allowlist has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| allowlist `indexed` | address | The new Allowlist |

### SetBalanceCommittedToDeposit

```solidity
event SetBalanceCommittedToDeposit(uint256 oldAmount, uint256 newAmount)
```

Emitted when the balance committed to deposit



#### Parameters

| Name | Type | Description |
|---|---|---|
| oldAmount  | uint256 | The old balance committed to deposit |
| newAmount  | uint256 | The new balance committed to deposit |

### SetBalanceToDeposit

```solidity
event SetBalanceToDeposit(uint256 oldAmount, uint256 newAmount)
```

Emitted when the balance to deposit is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| oldAmount  | uint256 | The old balance to deposit |
| newAmount  | uint256 | The new balance to deposit |

### SetBalanceToRedeem

```solidity
event SetBalanceToRedeem(uint256 oldAmount, uint256 newAmount)
```

Emitted when the balance to redeem is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| oldAmount  | uint256 | The old balance to redeem |
| newAmount  | uint256 | The new balance to redeem |

### SetBounds

```solidity
event SetBounds(uint256 annualAprUpperBound, uint256 relativeLowerBound)
```

The Report Bounds are changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| annualAprUpperBound  | uint256 | The reporting upper bound |
| relativeLowerBound  | uint256 | The reporting lower bound |

### SetCollector

```solidity
event SetCollector(address indexed collector)
```

The stored Collector has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| collector `indexed` | address | The new Collector |

### SetCoverageFund

```solidity
event SetCoverageFund(address indexed coverageFund)
```

The stored Coverage Fund has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| coverageFund `indexed` | address | The new Coverage Fund |

### SetDepositContractAddress

```solidity
event SetDepositContractAddress(address indexed depositContract)
```

The stored deposit contract address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| depositContract `indexed` | address | Address of the deposit contract |

### SetDepositedValidatorCount

```solidity
event SetDepositedValidatorCount(uint256 oldDepositedValidatorCount, uint256 newDepositedValidatorCount)
```

Emitted when the deposited validator count is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| oldDepositedValidatorCount  | uint256 | The old deposited validator count value |
| newDepositedValidatorCount  | uint256 | The new deposited validator count value |

### SetELFeeRecipient

```solidity
event SetELFeeRecipient(address indexed elFeeRecipient)
```

The stored Execution Layer Fee Recipient has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| elFeeRecipient `indexed` | address | The new Execution Layer Fee Recipient |

### SetGlobalFee

```solidity
event SetGlobalFee(uint256 fee)
```

The stored Global Fee has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| fee  | uint256 | The new Global Fee |

### SetMaxDailyCommittableAmounts

```solidity
event SetMaxDailyCommittableAmounts(uint256 minNetAmount, uint256 maxRelativeAmount)
```

Emitted when the daily committable limits are changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| minNetAmount  | uint256 | The minimum amount that must be used as the daily committable amount |
| maxRelativeAmount  | uint256 | The maximum amount that can be used as the daily committable amount, relative to the total underlying supply |

### SetMetadataURI

```solidity
event SetMetadataURI(string metadataURI)
```

The stored Metadata URI string has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| metadataURI  | string | The new Metadata URI string |

### SetOperatorsRegistry

```solidity
event SetOperatorsRegistry(address indexed operatorRegistry)
```

The stored Operators Registry has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| operatorRegistry `indexed` | address | The new Operators Registry |

### SetOracle

```solidity
event SetOracle(address indexed oracleAddress)
```

The stored oracle address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| oracleAddress `indexed` | address | The new oracle address |

### SetPendingAdmin

```solidity
event SetPendingAdmin(address indexed pendingAdmin)
```

The pending admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| pendingAdmin `indexed` | address | New pending admin address |

### SetRedeemManager

```solidity
event SetRedeemManager(address redeemManager)
```

Emitted when the redeem manager address is changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| redeemManager  | address | The address of the redeem manager |

### SetSpec

```solidity
event SetSpec(uint64 epochsPerFrame, uint64 slotsPerEpoch, uint64 secondsPerSlot, uint64 genesisTime, uint64 epochsToAssumedFinality)
```

The Consensus Layer Spec is changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| epochsPerFrame  | uint64 | The number of epochs inside a frame |
| slotsPerEpoch  | uint64 | The number of slots inside an epoch |
| secondsPerSlot  | uint64 | The number of seconds inside a slot |
| genesisTime  | uint64 | The genesis timestamp |
| epochsToAssumedFinality  | uint64 | The number of epochs before an epoch is considered final |

### SetTotalSupply

```solidity
event SetTotalSupply(uint256 totalSupply)
```

Emitted when the total supply is changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| totalSupply  | uint256 | undefined |

### SetWithdrawalCredentials

```solidity
event SetWithdrawalCredentials(bytes32 withdrawalCredentials)
```

The stored withdrawal credentials changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| withdrawalCredentials  | bytes32 | The withdrawal credentials to use for deposits |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```



*Emitted when `value` tokens are moved from one account (`from`) to another (`to`). Note that `value` may be zero.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| value  | uint256 | undefined |

### UserDeposit

```solidity
event UserDeposit(address indexed depositor, address indexed recipient, uint256 amount)
```

User deposited ETH in the system



#### Parameters

| Name | Type | Description |
|---|---|---|
| depositor `indexed` | address | Address performing the deposit |
| recipient `indexed` | address | Address receiving the minted shares |
| amount  | uint256 | Amount in ETH deposited |



## Errors

### AllowanceTooLow

```solidity
error AllowanceTooLow(address _from, address _operator, uint256 _allowance, uint256 _value)
```

Allowance too low to perform operation



#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | Account where funds are sent from |
| _operator | address | Account attempting the transfer |
| _allowance | uint256 | Current allowance |
| _value | uint256 | Requested transfer value in shares |

### BalanceTooLow

```solidity
error BalanceTooLow()
```

Balance too low to perform operation




### Denied

```solidity
error Denied(address account)
```

The access was denied



#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | The account that was denied |

### EmptyDeposit

```solidity
error EmptyDeposit()
```

And empty deposit attempt was made




### ErrorOnDeposit

```solidity
error ErrorOnDeposit()
```

An error occured during the deposit




### InconsistentPublicKeys

```solidity
error InconsistentPublicKeys()
```

The length of the BLS Public key is invalid during deposit




### InconsistentSignatures

```solidity
error InconsistentSignatures()
```

The length of the BLS Signature is invalid during deposit




### InvalidArgument

```solidity
error InvalidArgument()
```

The argument was invalid




### InvalidCall

```solidity
error InvalidCall()
```

The call was invalid




### InvalidDecreasingValidatorsExitedBalance

```solidity
error InvalidDecreasingValidatorsExitedBalance(uint256 currentValidatorsExitedBalance, uint256 newValidatorsExitedBalance)
```

The total exited balance decreased



#### Parameters

| Name | Type | Description |
|---|---|---|
| currentValidatorsExitedBalance | uint256 | The current exited balance |
| newValidatorsExitedBalance | uint256 | The new exited balance |

### InvalidDecreasingValidatorsSkimmedBalance

```solidity
error InvalidDecreasingValidatorsSkimmedBalance(uint256 currentValidatorsSkimmedBalance, uint256 newValidatorsSkimmedBalance)
```

The total skimmed balance decreased



#### Parameters

| Name | Type | Description |
|---|---|---|
| currentValidatorsSkimmedBalance | uint256 | The current exited balance |
| newValidatorsSkimmedBalance | uint256 | The new exited balance |

### InvalidDepositRoot

```solidity
error InvalidDepositRoot()
```

Invalid deposit root




### InvalidEmptyString

```solidity
error InvalidEmptyString()
```

The string is empty




### InvalidEpoch

```solidity
error InvalidEpoch(uint256 epoch)
```

Thrown when an invalid epoch was reported



#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch | uint256 | Invalid epoch |

### InvalidFee

```solidity
error InvalidFee()
```

The fee is invalid




### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```

An error occured during the initialization



#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | The version that was attempting to be initialized |
| expectedVersion | uint256 | The version that was expected |

### InvalidPublicKeyCount

```solidity
error InvalidPublicKeyCount()
```

The received count of public keys to deposit is invalid




### InvalidPulledClFundsAmount

```solidity
error InvalidPulledClFundsAmount(uint256 requested, uint256 received)
```

Thrown when the amount received from the Withdraw contract doe not match the requested amount



#### Parameters

| Name | Type | Description |
|---|---|---|
| requested | uint256 | The amount that was requested |
| received | uint256 | The amount that was received |

### InvalidSignatureCount

```solidity
error InvalidSignatureCount()
```

The received count of signatures to deposit is invalid




### InvalidValidatorCountReport

```solidity
error InvalidValidatorCountReport(uint256 providedValidatorCount, uint256 depositedValidatorCount, uint256 lastReportedValidatorCount)
```

The reported validator count is invalid



#### Parameters

| Name | Type | Description |
|---|---|---|
| providedValidatorCount | uint256 | The received validator count value |
| depositedValidatorCount | uint256 | The number of deposits performed by the system |
| lastReportedValidatorCount | uint256 | The last reported validator count |

### InvalidWithdrawalCredentials

```solidity
error InvalidWithdrawalCredentials()
```

The withdrawal credentials value is null




### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero




### NoAvailableValidatorKeys

```solidity
error NoAvailableValidatorKeys()
```

The internal key retrieval returned no keys




### NotEnoughFunds

```solidity
error NotEnoughFunds()
```

Not enough funds to deposit one validator




### NullTransfer

```solidity
error NullTransfer()
```

Invalid empty transfer




### OnlyKeeper

```solidity
error OnlyKeeper()
```






### SliceOutOfBounds

```solidity
error SliceOutOfBounds()
```

The slice is outside of the initial bytes bounds




### SliceOverflow

```solidity
error SliceOverflow()
```

The length overflows an uint




### TotalValidatorBalanceDecreaseOutOfBound

```solidity
error TotalValidatorBalanceDecreaseOutOfBound(uint256 prevTotalEthIncludingExited, uint256 postTotalEthIncludingExited, uint256 timeElapsed, uint256 relativeLowerBound)
```

The balance decrease is higher than the maximum allowed by the lower bound



#### Parameters

| Name | Type | Description |
|---|---|---|
| prevTotalEthIncludingExited | uint256 | The previous total balance, including all exited balance |
| postTotalEthIncludingExited | uint256 | The post-report total balance, including all exited balance |
| timeElapsed | uint256 | The time in seconds since last report |
| relativeLowerBound | uint256 | The lower bound value that was used |

### TotalValidatorBalanceIncreaseOutOfBound

```solidity
error TotalValidatorBalanceIncreaseOutOfBound(uint256 prevTotalEthIncludingExited, uint256 postTotalEthIncludingExited, uint256 timeElapsed, uint256 annualAprUpperBound)
```

The balance increase is higher than the maximum allowed by the upper bound



#### Parameters

| Name | Type | Description |
|---|---|---|
| prevTotalEthIncludingExited | uint256 | The previous total balance, including all exited balance |
| postTotalEthIncludingExited | uint256 | The post-report total balance, including all exited balance |
| timeElapsed | uint256 | The time in seconds since last report |
| annualAprUpperBound | uint256 | The upper bound value that was used |

### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Address performing the call |

### UnauthorizedTransfer

```solidity
error UnauthorizedTransfer(address _from, address _to)
```

Invalid transfer recipients



#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | Account sending the funds in the invalid transfer |
| _to | address | Account receiving the funds in the invalid transfer |

### ZeroMintedShares

```solidity
error ZeroMintedShares()
```

The computed amount of shares to mint is 0





