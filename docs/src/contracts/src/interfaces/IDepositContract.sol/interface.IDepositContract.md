# IDepositContract
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/IDepositContract.sol)

**Title:**
Deposit Contract Interface

This interface exposes methods to perform validator deposits


## Functions
### deposit

Official deposit method to activate a validator on the consensus layer


```solidity
function deposit(
    bytes calldata pubkey,
    bytes calldata withdrawalCredentials,
    bytes calldata signature,
    bytes32 depositDataRoot
) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|The 48 bytes long BLS Public key representing the validator|
|`withdrawalCredentials`|`bytes`|The 32 bytes long withdrawal credentials, configures the withdrawal recipient|
|`signature`|`bytes`|The 96 bytes long BLS Signature performed by the pubkey's private key|
|`depositDataRoot`|`bytes32`|The root hash of the whole deposit data structure|


### get_deposit_root

Query the current deposit root hash.


```solidity
function get_deposit_root() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The deposit root hash.|


