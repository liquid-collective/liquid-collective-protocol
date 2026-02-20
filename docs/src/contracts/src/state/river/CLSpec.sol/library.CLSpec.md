# CLSpec
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/CLSpec.sol)

**Title:**
Consensus Layer Spec Storage

Utility to manage the Consensus Layer Spec in storage


## State Variables
### CL_SPEC_SLOT
Storage slot of the Consensus Layer Spec


```solidity
bytes32 internal constant CL_SPEC_SLOT = bytes32(uint256(keccak256("river.state.clSpec")) - 1)
```


## Functions
### get

Retrieve the Consensus Layer Spec from storage


```solidity
function get() internal view returns (CLSpecStruct memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CLSpecStruct`|The Consensus Layer Spec|


### set

Set the Consensus Layer Spec value in storage


```solidity
function set(CLSpecStruct memory _newCLSpec) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newCLSpec`|`CLSpecStruct`|The new value to set in storage|


## Structs
### CLSpecStruct
The Consensus Layer Spec structure


```solidity
struct CLSpecStruct {
    /// @custom:attribute The count of epochs per frame, 225 means 24h
    uint64 epochsPerFrame;
    /// @custom:attribute The count of slots in an epoch (32 on mainnet)
    uint64 slotsPerEpoch;
    /// @custom:attribute The seconds in a slot (12 on mainnet)
    uint64 secondsPerSlot;
    /// @custom:attribute The block timestamp of the first consensus layer block
    uint64 genesisTime;
    /// @custom:attribute The count of epochs before considering an epoch final on-chain
    uint64 epochsToAssumedFinality;
}
```

### Slot
The structure in storage


```solidity
struct Slot {
    /// @custom:attribute The structure in storage
    CLSpecStruct value;
}
```

