# WithdrawalCredentials
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/WithdrawalCredentials.sol)

**Title:**
Withdrawal Credentials Storage

Utility to manage the Withdrawal Credentials in storage


## State Variables
### WITHDRAWAL_CREDENTIALS_SLOT
Storage slot of the Withdrawal Credentials


```solidity
bytes32 internal constant WITHDRAWAL_CREDENTIALS_SLOT =
    bytes32(uint256(keccak256("river.state.withdrawalCredentials")) - 1)
```


## Functions
### get

Retrieve the Withdrawal Credentials


```solidity
function get() internal view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The Withdrawal Credentials|


### getAddress

Retrieve the Withdrawal Credential under its address format


```solidity
function getAddress() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Withdrawal Credentials in its address format|


### set

Sets the Withdrawal Credentials


```solidity
function set(bytes32 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`bytes32`|New Withdrawal Credentials|


