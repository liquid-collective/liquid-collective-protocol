# MetadataURI
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/MetadataURI.sol)

**Title:**
Metadata URI Storage

Utility to manage the Metadata in storage


## State Variables
### METADATA_URI_SLOT
Storage slot of the Metadata URI


```solidity
bytes32 internal constant METADATA_URI_SLOT = bytes32(uint256(keccak256("river.state.metadataUri")) - 1)
```


## Functions
### get

Retrieve the metadata URI


```solidity
function get() internal view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The metadata URI string|


### set

Set the metadata URI value


```solidity
function set(string memory _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`string`|The new metadata URI value|


## Structs
### Slot
Structure in storage


```solidity
struct Slot {
    /// @custom:attribute The metadata value
    string value;
}
```

