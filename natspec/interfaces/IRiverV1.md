# IRiverV1









## Methods

### acceptOwnership

```solidity
function acceptOwnership() external nonpayable
```






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
function deposit() external payable
```






### depositAndTransfer

```solidity
function depositAndTransfer(address _recipient) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _recipient | address | undefined |

### depositToConsensusLayer

```solidity
function depositToConsensusLayer(uint256 _maxCount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _maxCount | uint256 | undefined |

### getAdministrator

```solidity
function getAdministrator() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getAllowlist

```solidity
function getAllowlist() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getBeaconValidatorBalanceSum

```solidity
function getBeaconValidatorBalanceSum() external view returns (uint256 beaconValidatorBalanceSum)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| beaconValidatorBalanceSum | uint256 | undefined |

### getBeaconValidatorCount

```solidity
function getBeaconValidatorCount() external view returns (uint256 beaconValidatorCount)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| beaconValidatorCount | uint256 | undefined |

### getDepositedValidatorCount

```solidity
function getDepositedValidatorCount() external view returns (uint256 depositedValidatorCount)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| depositedValidatorCount | uint256 | undefined |

### getELFeeRecipient

```solidity
function getELFeeRecipient() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getOracle

```solidity
function getOracle() external view returns (address oracle)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| oracle | address | undefined |

### getPendingAdministrator

```solidity
function getPendingAdministrator() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getPendingEth

```solidity
function getPendingEth() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getTreasury

```solidity
function getTreasury() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getWithdrawalCredentials

```solidity
function getWithdrawalCredentials() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### initRiverV1

```solidity
function initRiverV1(address _depositContractAddress, address _elFeeRecipientAddress, bytes32 _withdrawalCredentials, address _oracleAddress, address _systemAdministratorAddress, address _allowlistAddress, address _operatorRegistryAddress, address _treasuryAddress, uint256 _globalFee, uint256 _operatorRewardsShare) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _depositContractAddress | address | undefined |
| _elFeeRecipientAddress | address | undefined |
| _withdrawalCredentials | bytes32 | undefined |
| _oracleAddress | address | undefined |
| _systemAdministratorAddress | address | undefined |
| _allowlistAddress | address | undefined |
| _operatorRegistryAddress | address | undefined |
| _treasuryAddress | address | undefined |
| _globalFee | uint256 | undefined |
| _operatorRewardsShare | uint256 | undefined |

### name

```solidity
function name() external pure returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### sendELFees

```solidity
function sendELFees() external payable
```






### setAllowlist

```solidity
function setAllowlist(address _newAllowlist) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAllowlist | address | undefined |

### setBeaconData

```solidity
function setBeaconData(uint256 _validatorCount, uint256 _validatorBalanceSum, bytes32 _roundId) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _validatorCount | uint256 | undefined |
| _validatorBalanceSum | uint256 | undefined |
| _roundId | bytes32 | undefined |

### setELFeeRecipient

```solidity
function setELFeeRecipient(address _newELFeeRecipient) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newELFeeRecipient | address | undefined |

### setOperatorRewardsShare

```solidity
function setOperatorRewardsShare(uint256 newOperatorRewardsShare) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newOperatorRewardsShare | uint256 | undefined |

### setOracle

```solidity
function setOracle(address _oracleAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _oracleAddress | address | undefined |

### setTreasury

```solidity
function setTreasury(address _newTreasury) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newTreasury | address | undefined |

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






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```



*Returns the amount of tokens in existence.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### totalUnderlyingSupply

```solidity
function totalUnderlyingSupply() external view returns (uint256)
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

### transferOwnership

```solidity
function transferOwnership(address _newAdmin) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | undefined |

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






### ZeroMintedShares

```solidity
error ZeroMintedShares()
```







