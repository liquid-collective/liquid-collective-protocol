# LastConsensusLayerReport
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/LastConsensusLayerReport.sol)

**Title:**
Last Consensus Layer Report Storage

Utility to manage the Last Consensus Layer Report in storage


## State Variables
### LAST_CONSENSUS_LAYER_REPORT_SLOT
Storage slot of the Last Consensus Layer Report


```solidity
bytes32 internal constant LAST_CONSENSUS_LAYER_REPORT_SLOT =
    bytes32(uint256(keccak256("river.state.lastConsensusLayerReport")) - 1)
```


## Functions
### get

Retrieve the Last Consensus Layer Report from storage


```solidity
function get() internal view returns (IOracleManagerV1.StoredConsensusLayerReport storage);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IOracleManagerV1.StoredConsensusLayerReport`|The Last Consensus Layer Report|


### set

Set the Last Consensus Layer Report value in storage


```solidity
function set(IOracleManagerV1.StoredConsensusLayerReport memory _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`IOracleManagerV1.StoredConsensusLayerReport`|The new value to set in storage|


## Structs
### Slot
The structure in storage


```solidity
struct Slot {
    /// @custom:attribute The structure in storage
    IOracleManagerV1.StoredConsensusLayerReport value;
}
```

