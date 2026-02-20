# OracleAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/OracleAddress.sol)

**Title:**
Oracle Address Storage

Utility to manage the Oracle Address in storage


## State Variables
### ORACLE_ADDRESS_SLOT
Storage slot of the Oracle Address


```solidity
bytes32 internal constant ORACLE_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.oracleAddress")) - 1)
```


## Functions
### get

Retrieve the Oracle Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Oracle Address|


### set

Sets the Oracle Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Oracle Address|


