# LastOracleRoundId
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/LastOracleRoundId.sol)

**Title:**
Last Oracle Round Id Storage

Utility to manage the Last Oracle Round Id in storage

This state variable is deprecated and was kept due to migration logic needs


## State Variables
### LAST_ORACLE_ROUND_ID_SLOT
Storage slot of the Last Oracle Round Id


```solidity
bytes32 internal constant LAST_ORACLE_ROUND_ID_SLOT =
    bytes32(uint256(keccak256("river.state.lastOracleRoundId")) - 1)
```


## Functions
### get

Retrieve the Last Oracle Round Id


```solidity
function get() internal view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The Last Oracle Round Id|


### set

Sets the Last Oracle Round Id


```solidity
function set(bytes32 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`bytes32`|New Last Oracle Round Id|


