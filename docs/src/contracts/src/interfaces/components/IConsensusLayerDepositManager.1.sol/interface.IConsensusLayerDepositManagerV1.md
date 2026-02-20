# IConsensusLayerDepositManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/components/IConsensusLayerDepositManager.1.sol)

**Title:**
Consensys Layer Deposit Manager Interface (v1)

**Author:**
Alluvial Finance Inc.

This interface exposes methods to handle the interactions with the official deposit contract


## Functions
### getBalanceToDeposit

Returns the amount of ETH not yet committed for deposit


```solidity
function getBalanceToDeposit() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of ETH not yet committed for deposit|


### getCommittedBalance

Returns the amount of ETH committed for deposit


```solidity
function getCommittedBalance() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of ETH committed for deposit|


### getWithdrawalCredentials

Retrieve the withdrawal credentials


```solidity
function getWithdrawalCredentials() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The withdrawal credentials|


### getDepositedValidatorCount

Get the deposited validator count (the count of deposits made by the contract)


```solidity
function getDepositedValidatorCount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The deposited validator count|


### getKeeper

Get the keeper address


```solidity
function getKeeper() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The keeper address|


### depositToConsensusLayerWithDepositRoot

Deposits current balance to the Consensus Layer based on explicit operator allocations


```solidity
function depositToConsensusLayerWithDepositRoot(
    IOperatorsRegistryV1.OperatorAllocation[] calldata _allocations,
    bytes32 _depositRoot
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_allocations`|`IOperatorsRegistryV1.OperatorAllocation[]`|The operator allocations specifying how many validators per operator|
|`_depositRoot`|`bytes32`|The root of the deposit tree|


## Events
### SetDepositContractAddress
The stored deposit contract address changed


```solidity
event SetDepositContractAddress(address indexed depositContract);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositContract`|`address`|Address of the deposit contract|

### SetWithdrawalCredentials
The stored withdrawal credentials changed


```solidity
event SetWithdrawalCredentials(bytes32 withdrawalCredentials);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`withdrawalCredentials`|`bytes32`|The withdrawal credentials to use for deposits|

### SetDepositedValidatorCount
Emitted when the deposited validator count is updated


```solidity
event SetDepositedValidatorCount(uint256 oldDepositedValidatorCount, uint256 newDepositedValidatorCount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldDepositedValidatorCount`|`uint256`|The old deposited validator count value|
|`newDepositedValidatorCount`|`uint256`|The new deposited validator count value|

## Errors
### NotEnoughFunds
Not enough funds to deposit one validator


```solidity
error NotEnoughFunds();
```

### InconsistentPublicKeys
The length of the BLS Public key is invalid during deposit


```solidity
error InconsistentPublicKeys();
```

### InconsistentSignatures
The length of the BLS Signature is invalid during deposit


```solidity
error InconsistentSignatures();
```

### NoAvailableValidatorKeys
The internal key retrieval returned no keys


```solidity
error NoAvailableValidatorKeys();
```

### InvalidPublicKeyCount
The received count of public keys to deposit is invalid


```solidity
error InvalidPublicKeyCount();
```

### InvalidWithdrawalCredentials
The withdrawal credentials value is null


```solidity
error InvalidWithdrawalCredentials();
```

### ErrorOnDeposit
An error occured during the deposit


```solidity
error ErrorOnDeposit();
```

### InvalidDepositRoot
Invalid deposit root


```solidity
error InvalidDepositRoot();
```

### OnlyKeeper

```solidity
error OnlyKeeper();
```

### OperatorAllocationsExceedCommittedBalance
The operator allocations exceed the committed balance


```solidity
error OperatorAllocationsExceedCommittedBalance();
```

