# DepositContractAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/DepositContractAddress.sol)

**Title:**
Deposit Contract Address Storage

Utility to manage the Deposit Contract Address in storage


## State Variables
### DEPOSIT_CONTRACT_ADDRESS_SLOT
Storage slot of the Deposit Contract Address


```solidity
bytes32 internal constant DEPOSIT_CONTRACT_ADDRESS_SLOT =
    bytes32(uint256(keccak256("river.state.depositContractAddress")) - 1)
```


## Functions
### get

Retrieve the Deposit Contract Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Deposit Contract Address|


### set

Sets the Deposit Contract Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Deposit Contract Address|


