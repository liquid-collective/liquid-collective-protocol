# ConsensusLayerDepositManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/components/ConsensusLayerDepositManager.1.sol)

**Inherits:**
[IConsensusLayerDepositManagerV1](/contracts/src/interfaces/components/IConsensusLayerDepositManager.1.sol/interface.IConsensusLayerDepositManagerV1.md)

**Title:**
Consensus Layer Deposit Manager (v1)

**Author:**
Alluvial Finance Inc.

This contract handles the interactions with the official deposit contract, funding all validators

Whenever a deposit to the consensus layer is requested, this contract computed the amount of keys

that could be deposited depending on the amount available in the contract. It then tries to retrieve

validator keys by calling its internal virtual method _getNextValidators. This method should be

overridden by the implementing contract to provide keys based on the allocation when invoked.


## State Variables
### PUBLIC_KEY_LENGTH
Size of a BLS Public key in bytes


```solidity
uint256 public constant PUBLIC_KEY_LENGTH = 48
```


### SIGNATURE_LENGTH
Size of a BLS Signature in bytes


```solidity
uint256 public constant SIGNATURE_LENGTH = 96
```


### DEPOSIT_SIZE
Size of a deposit in ETH


```solidity
uint256 public constant DEPOSIT_SIZE = 32 ether
```


## Functions
### _getRiverAdmin

Handler called to retrieve the internal River admin address

Must be Overridden


```solidity
function _getRiverAdmin() internal view virtual returns (address);
```

### _setCommittedBalance

Handler called to change the committed balance to deposit


```solidity
function _setCommittedBalance(uint256 newCommittedBalance) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCommittedBalance`|`uint256`|The new committed balance value|


### _getNextValidators

Internal helper to retrieve validator keys ready to be funded

Must be overridden


```solidity
function _getNextValidators(IOperatorsRegistryV1.OperatorAllocation[] memory _allocations)
    internal
    virtual
    returns (bytes[] memory publicKeys, bytes[] memory signatures);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_allocations`|`IOperatorsRegistryV1.OperatorAllocation[]`|Validator allocations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKeys`|`bytes[]`|An array of public keys ready to be funded|
|`signatures`|`bytes[]`|An array of signatures ready to be funded|


### initConsensusLayerDepositManagerV1

Initializer to set the deposit contract address and the withdrawal credentials to use


```solidity
function initConsensusLayerDepositManagerV1(address _depositContractAddress, bytes32 _withdrawalCredentials)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_depositContractAddress`|`address`|The address of the deposit contract|
|`_withdrawalCredentials`|`bytes32`|The withdrawal credentials to apply to all deposits|


### _setKeeper


```solidity
function _setKeeper(address _keeper) internal;
```

### getCommittedBalance

Returns the amount of ETH committed for deposit


```solidity
function getCommittedBalance() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of ETH committed for deposit|


### getBalanceToDeposit

Returns the amount of ETH not yet committed for deposit


```solidity
function getBalanceToDeposit() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of ETH not yet committed for deposit|


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


### _depositValidator

Deposits 32 ETH to the official Deposit contract


```solidity
function _depositValidator(bytes memory _publicKey, bytes memory _signature, bytes32 _withdrawalCredentials)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_publicKey`|`bytes`|The public key of the validator|
|`_signature`|`bytes`|The signature provided by the operator|
|`_withdrawalCredentials`|`bytes32`|The withdrawal credentials provided by River|


