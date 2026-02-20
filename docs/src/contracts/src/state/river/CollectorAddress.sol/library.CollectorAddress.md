# CollectorAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/CollectorAddress.sol)

**Title:**
Collector Address Storage

Utility to manage the Collector Address in storage


## State Variables
### COLLECTOR_ADDRESS_SLOT
Storage slot of the Collector Address


```solidity
bytes32 internal constant COLLECTOR_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.collectorAddress")) - 1)
```


## Functions
### get

Retrieve the Collector Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Collector Address|


### set

Sets the Collector Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Collector Address|


