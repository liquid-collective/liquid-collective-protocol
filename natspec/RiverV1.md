# RiverV1

*Kiln*

> River (v1)

This contract merges all the manager contracts and implements all the virtual methods stitching all components together@notice    +---------------------------------------------------------------------+|                                                                     ||                           Consensus Layer                           ||                                                                     || +-------------------+  +-------------------+  +-------------------+ || |                   |  |                   |  |                   | || |  EL Fee Recipient |  |      Oracle       |  |  Deposit Contract | || |                   |  |                   |  |                   | || +---------|---------+  +---------|---------+  +---------|---------+ |+---------------------------------------------------------------------+|         7            |            5         |+-----------------|    |    |-----------------+|    |6   ||    |    |+---------+          +----|----|----|----+            +---------+|         |          |                   |     2      |         ||Operator |          |       River       --------------  User   ||         |          |                   |            |         |+----|----+          +----|---------|----+            +---------+|                    |         ||             4      |         |       3|1     +-------------|         |--------------+|      |                                      ||      |                                      |+------|------|------------+           +-------------|------------+|                          |           |                          ||    Operators Registry    |           |         Allowlist        ||                          |           |                          |+--------------------------+           +--------------------------+@notice      1. Operators are adding BLS Public Keys of validators running in theirinfrastructure.2. User deposit ETH to the system and get shares minted in exchange3. Upon deposit, the system verifies if the User is allowed to depositby querying the Allowlist4. When the system has enough funds to deposit validators, keys are pulledfrom the Operators Registry5. The deposit data is computed and the validators are funded via the officialdeposit contract6. Oracles report the total balance of the running validators and the total countof running validators7. The running validators propose blocks that reward the EL Fee Recipient. The fundsare pulled back in the system.



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
| _0 | uint256 | The allowance for a given spender |

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
| _value | uint256 | The allowed amount, will override previous value |

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
| _0 | uint256 | The balance of the account |

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
| _subtractableValue | uint256 | Amount to subtract |

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
| _recipient | address | Address receiving the minted lsETH |

### depositToConsensusLayer

```solidity
function depositToConsensusLayer(uint256 _maxCount) external nonpayable
```

Deposits current balance to the Consensus Layer by batches of 32 ETH



#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxCount | uint256 | The maximum amount of validator keys to fund |

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

Returns the amount of pending ETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of pending eth |

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

### getGlobalFee

```solidity
function getGlobalFee() external view returns (uint256)
```

Get the current global fee




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The global fee |

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
| _additionalValue | uint256 | Amount to add |

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
| _globalFee | uint256 | Amount retained when the eth balance increases, splitted between the collector and the operators |

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

*This security prevents setting an invalid address as an admin. The pendingadmin has to claim its ownership of the contract, and proves that the newaddress is able to perform regular transactions.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | New admin address |

### sendELFees

```solidity
function sendELFees() external payable
```

Input for execution layer fee earnings




### setAllowlist

```solidity
function setAllowlist(address _newAllowlist) external nonpayable
```

Changes the allowlist address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAllowlist | address | New address for the allowlist |

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
function setConsensusLayerData(uint256 _validatorCount, uint256 _validatorTotalBalance, bytes32 _roundId, uint256 _maxIncrease) external nonpayable
```

Sets the validator count and validator total balance sum reported by the oracle

*Can only be called by the oracle addressThe round id is a blackbox value that should only be used to identify unique reportsWhen a report is performed, River computes the amount of fees that can be pulledfrom the execution layer fee recipient. This amount is capped by the max allowedincrease provided during the report.If the total asset balance increases (from the reported total balance and the pulled funds)we then compute the share that must be taken for the collector on the positive delta.The execution layer fees are taken into account here because they are the product ofnode operator&#39;s work, just like consensus layer fees, and both should be handled in thesame manner, as a single revenue stream for the users and the collector.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _validatorCount | uint256 | The number of active validators on the consensus layer |
| _validatorTotalBalance | uint256 | The validator balance sum of the active validators on the consensus layer |
| _roundId | bytes32 | An identifier for this update |
| _maxIncrease | uint256 | The maximum allowed increase in the total balance |

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
function setGlobalFee(uint256 newFee) external nonpayable
```

Changes the global fee parameter



#### Parameters

| Name | Type | Description |
|---|---|---|
| newFee | uint256 | New fee value |

### setOracle

```solidity
function setOracle(address _oracleAddress) external nonpayable
```

Set the oracle address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleAddress | address | Address of the oracle |

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
| _0 | uint256 | The total supply |

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
| _value | uint256 | Amount to be sent |

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
| _value | uint256 | Amount to be sent |

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



## Events

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```





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
| validatorCount  | uint256 | undefined |
| validatorTotalBalance  | uint256 | undefined |
| roundId  | bytes32 | undefined |

### FundedValidatorKey

```solidity
event FundedValidatorKey(bytes publicKey)
```

A validator key got funded on the deposit contract



#### Parameters

| Name | Type | Description |
|---|---|---|
| publicKey  | bytes | undefined |

### Initialize

```solidity
event Initialize(uint256 version, bytes cdata)
```

Emitted when the contract is properly initialized



#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint256 | undefined |
| cdata  | bytes | undefined |

### PulledELFees

```solidity
event PulledELFees(uint256 amount)
```

Funds have been pulled from the Execution Layer Fee Recipient



#### Parameters

| Name | Type | Description |
|---|---|---|
| amount  | uint256 | undefined |

### SetAdmin

```solidity
event SetAdmin(address indexed admin)
```

The admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| admin `indexed` | address | undefined |

### SetAllowlist

```solidity
event SetAllowlist(address indexed allowlist)
```

The stored Allowlist has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| allowlist `indexed` | address | undefined |

### SetCollector

```solidity
event SetCollector(address indexed collector)
```

The stored Collector has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| collector `indexed` | address | undefined |

### SetDepositContractAddress

```solidity
event SetDepositContractAddress(address indexed depositContract)
```

The stored deposit contract address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| depositContract `indexed` | address | undefined |

### SetELFeeRecipient

```solidity
event SetELFeeRecipient(address indexed elFeeRecipient)
```

The stored Execution Layer Fee Recipient has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| elFeeRecipient `indexed` | address | undefined |

### SetGlobalFee

```solidity
event SetGlobalFee(uint256 fee)
```

The stored Global Fee has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| fee  | uint256 | undefined |

### SetOperatorsRegistry

```solidity
event SetOperatorsRegistry(address indexed operatorRegistry)
```

The stored Operators Registry has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| operatorRegistry `indexed` | address | undefined |

### SetOracle

```solidity
event SetOracle(address indexed oracleAddress)
```

The storage oracle address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| oracleAddress `indexed` | address | undefined |

### SetPendingAdmin

```solidity
event SetPendingAdmin(address indexed pendingAdmin)
```

The pending admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| pendingAdmin `indexed` | address | undefined |

### SetWithdrawalCredentials

```solidity
event SetWithdrawalCredentials(bytes32 withdrawalCredentials)
```

The stored withdrawals credentials changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| withdrawalCredentials  | bytes32 | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```





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

User deposited eth in the system



#### Parameters

| Name | Type | Description |
|---|---|---|
| depositor `indexed` | address | undefined |
| recipient `indexed` | address | undefined |
| amount  | uint256 | undefined |



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
| _value | uint256 | Requested transfer value |

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
| version | uint256 | The version that was attempting the be initialized |
| expectedVersion | uint256 | The version that was expected |

### InvalidPublicKeyCount

```solidity
error InvalidPublicKeyCount()
```

The received count of public keys to deposit is invalid




### InvalidSignatureCount

```solidity
error InvalidSignatureCount()
```

The received count of signatures to deposit is invalid




### InvalidValidatorCountReport

```solidity
error InvalidValidatorCountReport(uint256 providedValidatorCount, uint256 depositedValidatorCount)
```

The reported validator count is invalid



#### Parameters

| Name | Type | Description |
|---|---|---|
| providedValidatorCount | uint256 | The received validator count value |
| depositedValidatorCount | uint256 | The number of deposits performed by the system |

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




### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Addres performing the call |

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





