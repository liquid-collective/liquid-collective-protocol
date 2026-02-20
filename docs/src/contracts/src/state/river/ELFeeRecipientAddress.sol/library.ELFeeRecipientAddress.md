# ELFeeRecipientAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/ELFeeRecipientAddress.sol)

**Title:**
Execution Layer Fee Recipient Address Storage

Utility to manage the Execution Layer Fee Recipient Address in storage


## State Variables
### EL_FEE_RECIPIENT_ADDRESS
Storage slot of the Execution Layer Fee Recipient Address


```solidity
bytes32 internal constant EL_FEE_RECIPIENT_ADDRESS =
    bytes32(uint256(keccak256("river.state.elFeeRecipientAddress")) - 1)
```


## Functions
### get

Retrieve the Execution Layer Fee Recipient Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Execution Layer Fee Recipient Address|


### set

Sets the Execution Layer Fee Recipient Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Execution Layer Fee Recipient Address|


