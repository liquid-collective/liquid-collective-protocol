# OperatorsRegistryAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/OperatorsRegistryAddress.sol)

**Title:**
Operators Registry Address Storage

Utility to manage the Operators Registry Address in storage


## State Variables
### OPERATORS_REGISTRY_ADDRESS_SLOT
Storage slot of the Operators Registry Address


```solidity
bytes32 internal constant OPERATORS_REGISTRY_ADDRESS_SLOT =
    bytes32(uint256(keccak256("river.state.operatorsRegistryAddress")) - 1)
```


## Functions
### get

Retrieve the Operators Registry Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Operators Registry Address|


### set

Sets the Operators Registry Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Operators Registry Address|


