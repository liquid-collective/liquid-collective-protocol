# RiverV1

*Kiln*

> River (v1)

This contract merges all the manager contracts and implements all the virtual methods stitching all components together



## Methods

### BASE

```solidity
function BASE() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### DEPOSIT_SIZE

```solidity
function DEPOSIT_SIZE() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### PUBLIC_KEY_LENGTH

```solidity
function PUBLIC_KEY_LENGTH() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### SIGNATURE_LENGTH

```solidity
function SIGNATURE_LENGTH() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### acceptOwnership

```solidity
function acceptOwnership() external nonpayable
```

Accepts the ownership of the system




### allowance

```solidity
function allowance(address _owner, address _spender) external view returns (uint256 remaining)
```

Retrieve the allowance value for a spender_owner Address that issued the allowance_spender Address that received the allowance



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | undefined |
| _spender | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| remaining | uint256 | undefined |

### approve

```solidity
function approve(address _spender, uint256 _value) external nonpayable returns (bool success)
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
| success | bool | undefined |

### balanceOf

```solidity
function balanceOf(address _owner) external view returns (uint256 balance)
```

Retrieve the balance of an account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Address to be checked |

#### Returns

| Name | Type | Description |
|---|---|---|
| balance | uint256 | undefined |

### balanceOfUnderlying

```solidity
function balanceOfUnderlying(address _owner) external view returns (uint256 balance)
```

Retrieve the underlying asset balance of an account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Address to be checked |

#### Returns

| Name | Type | Description |
|---|---|---|
| balance | uint256 | undefined |

### decimals

```solidity
function decimals() external pure returns (uint8)
```

Retrieve the decimal count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

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

### getAdministrator

```solidity
function getAdministrator() external view returns (address)
```

Retrieve system administrator address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getAllowlist

```solidity
function getAllowlist() external view returns (address)
```

Retrieve the allowlist address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getBeaconValidatorBalanceSum

```solidity
function getBeaconValidatorBalanceSum() external view returns (uint256 beaconValidatorBalanceSum)
```

Get Beacon validator balance sum




#### Returns

| Name | Type | Description |
|---|---|---|
| beaconValidatorBalanceSum | uint256 | undefined |

### getBeaconValidatorCount

```solidity
function getBeaconValidatorCount() external view returns (uint256 beaconValidatorCount)
```

Get Beacon validator count (the amount of validator reported by the oracles)




#### Returns

| Name | Type | Description |
|---|---|---|
| beaconValidatorCount | uint256 | undefined |

### getDepositedValidatorCount

```solidity
function getDepositedValidatorCount() external view returns (uint256 depositedValidatorCount)
```

Get the deposited validator count (the count of deposits made by the contract)




#### Returns

| Name | Type | Description |
|---|---|---|
| depositedValidatorCount | uint256 | undefined |

### getELFeeRecipient

```solidity
function getELFeeRecipient() external view returns (address)
```

Retrieve the execution layer fee recipient




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getOracle

```solidity
function getOracle() external view returns (address oracle)
```

Get Oracle address




#### Returns

| Name | Type | Description |
|---|---|---|
| oracle | address | undefined |

### getPendingAdministrator

```solidity
function getPendingAdministrator() external view returns (address)
```

Retrieve system pending administrator address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getPendingEth

```solidity
function getPendingEth() external view returns (uint256)
```

Returns the amount of pending ETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getTreasury

```solidity
function getTreasury() external view returns (address)
```

Retrieve the treasury address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getWithdrawalCredentials

```solidity
function getWithdrawalCredentials() external view returns (bytes32)
```

Retrieve the withdrawal credentials




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### initRiverV1

```solidity
function initRiverV1(address _depositContractAddress, address _elFeeRecipientAddress, bytes32 _withdrawalCredentials, address _oracleAddress, address _systemAdministratorAddress, address _allowlistAddress, address _operatorRegistryAddress, address _treasuryAddress, uint256 _globalFee, uint256 _operatorRewardsShare) external nonpayable
```

Initializes the River system



#### Parameters

| Name | Type | Description |
|---|---|---|
| _depositContractAddress | address | Address to make Consensus Layer deposits |
| _elFeeRecipientAddress | address | Address that receives the execution layer fees |
| _withdrawalCredentials | bytes32 | Credentials to use for every validator deposit |
| _oracleAddress | address | undefined |
| _systemAdministratorAddress | address | Administrator address |
| _allowlistAddress | address | Address of the allowlist contract |
| _operatorRegistryAddress | address | Address of the operator registry |
| _treasuryAddress | address | Address receiving the fee minus the operator share |
| _globalFee | uint256 | Amount retained when the eth balance increases, splitted between the treasury and the operators |
| _operatorRewardsShare | uint256 | Share of the global fee used to reward node operators |

### name

```solidity
function name() external pure returns (string)
```

Retrieve the token name




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

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

### setBeaconData

```solidity
function setBeaconData(uint256 _validatorCount, uint256 _validatorBalanceSum, bytes32 _roundId) external nonpayable
```

Sets the validator count and validator balance sum reported by the oracle

*Can only be called by the oracle address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _validatorCount | uint256 | The number of active validators on the consensus layer |
| _validatorBalanceSum | uint256 | The validator balance sum of the active validators on the consensus layer |
| _roundId | bytes32 | An identifier for this update |

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

### setOperatorRewardsShare

```solidity
function setOperatorRewardsShare(uint256 newOperatorRewardsShare) external nonpayable
```

Changes the operator rewards share.



#### Parameters

| Name | Type | Description |
|---|---|---|
| newOperatorRewardsShare | uint256 | New share value |

### setOracle

```solidity
function setOracle(address _oracleAddress) external nonpayable
```

Set Oracle address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleAddress | address | Address of the oracle |

### setTreasury

```solidity
function setTreasury(address _newTreasury) external nonpayable
```

Changes the treasury address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newTreasury | address | New address for the treasury |

### sharesFromUnderlyingBalance

```solidity
function sharesFromUnderlyingBalance(uint256 underlyingBalance) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| underlyingBalance | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### symbol

```solidity
function symbol() external pure returns (string)
```

Retrieve the token symbol




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```

Retrieve the total token supply




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### totalUnderlyingSupply

```solidity
function totalUnderlyingSupply() external view returns (uint256)
```

Retrieve the total underlying asset supply




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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
| _0 | bool | undefined |

### transferFrom

```solidity
function transferFrom(address _from, address _to, uint256 _value) external nonpayable returns (bool)
```

Performs a transfer between two recipients

*If the specified _from argument is the message sender, behaves like a regular transferIf the specified _from argument is not the message sender, checks that the message sender has been given enough allowance*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | Address sending the tokens |
| _to | address | Address receiving the tokens |
| _value | uint256 | Amount to be sent |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferOwnership

```solidity
function transferOwnership(address _newAdmin) external nonpayable
```

Changes the admin but waits for new admin approval



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | New address for the admin |

### underlyingBalanceFromShares

```solidity
function underlyingBalanceFromShares(uint256 shares) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| shares | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |



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

### BeaconDataUpdate

```solidity
event BeaconDataUpdate(uint256 validatorCount, uint256 validatorBalanceSum, bytes32 roundId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| validatorCount  | uint256 | undefined |
| validatorBalanceSum  | uint256 | undefined |
| roundId  | bytes32 | undefined |

### FundedValidatorKey

```solidity
event FundedValidatorKey(bytes publicKey)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| publicKey  | bytes | undefined |

### PulledELFees

```solidity
event PulledELFees(uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount  | uint256 | undefined |

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





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _operator | address | undefined |
| _allowance | uint256 | undefined |
| _value | uint256 | undefined |

### BalanceTooLow

```solidity
error BalanceTooLow()
```






### EmptyDeposit

```solidity
error EmptyDeposit()
```






### EmptyDonation

```solidity
error EmptyDonation()
```






### InconsistentPublicKeys

```solidity
error InconsistentPublicKeys()
```






### InconsistentSignatures

```solidity
error InconsistentSignatures()
```






### InvalidArgument

```solidity
error InvalidArgument()
```






### InvalidCall

```solidity
error InvalidCall()
```






### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | undefined |
| expectedVersion | uint256 | undefined |

### InvalidPublicKeyCount

```solidity
error InvalidPublicKeyCount()
```






### InvalidSignatureCount

```solidity
error InvalidSignatureCount()
```






### InvalidValidatorCountReport

```solidity
error InvalidValidatorCountReport(uint256 _providedValidatorCount, uint256 _depositedValidatorCount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _providedValidatorCount | uint256 | undefined |
| _depositedValidatorCount | uint256 | undefined |

### InvalidWithdrawalCredentials

```solidity
error InvalidWithdrawalCredentials()
```






### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```






### NoAvailableValidatorKeys

```solidity
error NoAvailableValidatorKeys()
```






### NotEnoughFunds

```solidity
error NotEnoughFunds()
```






### NullTransfer

```solidity
error NullTransfer()
```






### Unauthorized

```solidity
error Unauthorized(address caller)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | undefined |

### ZeroMintedShares

```solidity
error ZeroMintedShares()
```







