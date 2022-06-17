# RiverV1

*SkillZ*

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

### addOperator

```solidity
function addOperator(string _name, address _operator) external nonpayable
```

Adds an operator to the registry

*Only callable by the administrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _name | string | The name identifying the operator |
| _operator | address | The address representing the operator, receiving the rewards |

### addValidators

```solidity
function addValidators(uint256 _index, uint256 _keyCount, bytes _publicKeys, bytes _signatures) external nonpayable
```

Adds new keys for an operator

*Only callable by the administrator or the operator address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _keyCount | uint256 | The amount of keys provided |
| _publicKeys | bytes | Public keys of the validator, concatenated |
| _signatures | bytes | Signatures of the validator keys, concatenated |

### allowance

```solidity
function allowance(address _owner, address _spender) external view returns (uint256 remaining)
```





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





#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | undefined |
| _value | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| success | bool | undefined |

### balanceOf

```solidity
function balanceOf(address _owner) external view returns (uint256 balance)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| balance | uint256 | undefined |

### balanceOfUnderlying

```solidity
function balanceOfUnderlying(address _owner) external view returns (uint256 balance)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| balance | uint256 | undefined |

### decimals

```solidity
function decimals() external pure returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### deposit

```solidity
function deposit(address _referral) external payable
```

Explicit deposit method



#### Parameters

| Name | Type | Description |
|---|---|---|
| _referral | address | Referral address, address(0) if none |

### depositToConsensusLayer

```solidity
function depositToConsensusLayer(uint256 _maxCount) external nonpayable
```

Deposits current balance to the Consensus Layer by batches of 32 ETH



#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxCount | uint256 | The maximum amount of validator keys to fund |

### donate

```solidity
function donate() external payable
```

Allows anyone to add ethers to river without minting new shares

*This method should be mainly used by the execution layer fee recipient to compound any collected fee*


### getAdministrator

```solidity
function getAdministrator() external view returns (address)
```

Retrieve system administrator address




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

### getOperator

```solidity
function getOperator(uint256 _index) external view returns (struct Operators.Operator)
```

Get operator details



#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The index of the operator |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | Operators.Operator | undefined |

### getOperatorByName

```solidity
function getOperatorByName(string _name) external view returns (struct Operators.Operator)
```

Get operator details by name



#### Parameters

| Name | Type | Description |
|---|---|---|
| _name | string | The name identifying the operator |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | Operators.Operator | undefined |

### getOperatorCount

```solidity
function getOperatorCount() external view returns (uint256)
```

Get operator count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getOperatorDetails

```solidity
function getOperatorDetails(string _name) external view returns (int256 _index, address _operatorAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _name | string | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _index | int256 | undefined |
| _operatorAddress | address | undefined |

### getOracle

```solidity
function getOracle() external view returns (address oracle)
```

Get Oracle address




#### Returns

| Name | Type | Description |
|---|---|---|
| oracle | address | undefined |

### getValidator

```solidity
function getValidator(uint256 _operatorIndex, uint256 _validatorIndex) external view returns (bytes publicKey, bytes signature, bool funded)
```

Get the details of a validator



#### Parameters

| Name | Type | Description |
|---|---|---|
| _operatorIndex | uint256 | The index of the operator |
| _validatorIndex | uint256 | The index of the validator |

#### Returns

| Name | Type | Description |
|---|---|---|
| publicKey | bytes | undefined |
| signature | bytes | undefined |
| funded | bool | undefined |

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
function initRiverV1(address _depositContractAddress, bytes32 _withdrawalCredentials, address _oracleAddress, address _systemAdministratorAddress, address _allowlistAddress, address _treasuryAddress, uint256 _globalFee, uint256 _operatorRewardsShare) external nonpayable
```

Initializes the River system



#### Parameters

| Name | Type | Description |
|---|---|---|
| _depositContractAddress | address | Address to make Consensus Layer deposits |
| _withdrawalCredentials | bytes32 | Credentials to use for every validator deposit |
| _oracleAddress | address | undefined |
| _systemAdministratorAddress | address | Administrator address |
| _allowlistAddress | address | Address of the allowlist contract |
| _treasuryAddress | address | Address receiving the fee minus the operator share |
| _globalFee | uint256 | Amount retained when the eth balance increases, splitted between the treasury and the operators |
| _operatorRewardsShare | uint256 | Share of the global fee used to reward node operators |

### name

```solidity
function name() external pure returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### removeValidators

```solidity
function removeValidators(uint256 _index, uint256[] _indexes) external nonpayable
```

Remove validator keys

*Only callable by the administrator or the operator addressThe indexes must be provided sorted in decreasing order, otherwise the method will revert*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _indexes | uint256[] | The indexes of the keys to remove |

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

### setGlobalFee

```solidity
function setGlobalFee(uint256 newFee) external nonpayable
```

Changes the global fee parameter



#### Parameters

| Name | Type | Description |
|---|---|---|
| newFee | uint256 | New fee value |

### setOperatorAddress

```solidity
function setOperatorAddress(uint256 _index, address _newOperatorAddress) external nonpayable
```

Changes the operator address of an operator

*Only callable by the administrator or the previous operator address*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _newOperatorAddress | address | The new address representing the operator |

### setOperatorLimit

```solidity
function setOperatorLimit(uint256 _index, uint256 _newLimit) external nonpayable
```

Changes the operator staking limit

*Only callable by the administrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _newLimit | uint256 | The new staking limit of the operator |

### setOperatorRewardsShare

```solidity
function setOperatorRewardsShare(uint256 newOperatorRewardsShare) external nonpayable
```

Changes the operator rewards share.



#### Parameters

| Name | Type | Description |
|---|---|---|
| newOperatorRewardsShare | uint256 | New share value |

### setOperatorStatus

```solidity
function setOperatorStatus(uint256 _index, bool _newStatus) external nonpayable
```

Changes the operator status

*Only callable by the administrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _newStatus | bool | The new status of the operator |

### setOperatorStoppedValidatorCount

```solidity
function setOperatorStoppedValidatorCount(uint256 _index, uint256 _newStoppedValidatorCount) external nonpayable
```

Changes the operator stopped validator cound

*Only callable by the administrator*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | The operator index |
| _newStoppedValidatorCount | uint256 | The new stopped validator count of the operator |

### setOracle

```solidity
function setOracle(address _oracleAddress) external nonpayable
```

Set Oracle address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleAddress | address | Address of the oracle |

### sharesOf

```solidity
function sharesOf(address _owner) external view returns (uint256 shares)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| shares | uint256 | undefined |

### symbol

```solidity
function symbol() external pure returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### totalShares

```solidity
function totalShares() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfer

```solidity
function transfer(address _to, uint256 _value) external nonpayable returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _to | address | undefined |
| _value | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferFrom

```solidity
function transferFrom(address _from, address _to, uint256 _value) external nonpayable returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _to | address | undefined |
| _value | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |



## Events

### AddedOperator

```solidity
event AddedOperator(uint256 indexed index, string name, address operatorAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| name  | string | undefined |
| operatorAddress  | address | undefined |

### AddedValidatorKeys

```solidity
event AddedValidatorKeys(uint256 indexed index, uint256 totalKeyCount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| totalKeyCount  | uint256 | undefined |

### Approval

```solidity
event Approval(address indexed _owner, address indexed _spender, uint256 _value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner `indexed` | address | undefined |
| _spender `indexed` | address | undefined |
| _value  | uint256 | undefined |

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

### Donation

```solidity
event Donation(address donator, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| donator  | address | undefined |
| amount  | uint256 | undefined |

### RemovedValidatorKeys

```solidity
event RemovedValidatorKeys(uint256 indexed index, uint256 keyCount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| keyCount  | uint256 | undefined |

### SetOperatorAddress

```solidity
event SetOperatorAddress(uint256 indexed index, address newOperatorAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newOperatorAddress  | address | undefined |

### SetOperatorLimit

```solidity
event SetOperatorLimit(uint256 indexed index, uint256 newLimit)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newLimit  | uint256 | undefined |

### SetOperatorStatus

```solidity
event SetOperatorStatus(uint256 indexed index, bool active)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| active  | bool | undefined |

### SetOperatorStoppedValidatorCount

```solidity
event SetOperatorStoppedValidatorCount(uint256 indexed index, uint256 newStoppedValidatorCount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index `indexed` | uint256 | undefined |
| newStoppedValidatorCount  | uint256 | undefined |

### Transfer

```solidity
event Transfer(address indexed _from, address indexed _to, uint256 _value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from `indexed` | address | undefined |
| _to `indexed` | address | undefined |
| _value  | uint256 | undefined |

### UserDeposit

```solidity
event UserDeposit(address indexed user, address indexed referral, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| user `indexed` | address | undefined |
| referral `indexed` | address | undefined |
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






### InactiveOperator

```solidity
error InactiveOperator(uint256 index)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | undefined |

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






### InvalidFundedKeyDeletionAttempt

```solidity
error InvalidFundedKeyDeletionAttempt()
```






### InvalidIndexOutOfBounds

```solidity
error InvalidIndexOutOfBounds()
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

### InvalidKeyCount

```solidity
error InvalidKeyCount()
```






### InvalidPublicKeyCount

```solidity
error InvalidPublicKeyCount()
```






### InvalidPublicKeysLength

```solidity
error InvalidPublicKeysLength()
```






### InvalidSignatureCount

```solidity
error InvalidSignatureCount()
```






### InvalidSignatureLength

```solidity
error InvalidSignatureLength()
```






### InvalidUnsortedIndexes

```solidity
error InvalidUnsortedIndexes()
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






### OperatorAlreadyExists

```solidity
error OperatorAlreadyExists(string name)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| name | string | undefined |

### OperatorNotFound

```solidity
error OperatorNotFound(string name)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| name | string | undefined |

### OperatorNotFoundAtIndex

```solidity
error OperatorNotFoundAtIndex(uint256 index)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | undefined |

### Unauthorized

```solidity
error Unauthorized(address caller)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | undefined |

### UnauthorizedOperation

```solidity
error UnauthorizedOperation()
```







