# ReportsPositions
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/oracle/ReportsPositions.sol)

**Title:**
Reports Positions Storage

Utility to manage the Reports Positions in storage

Each bit in the stored uint256 value tells if the member at a given index has reported


## State Variables
### REPORTS_POSITIONS_SLOT
Storage slot of the Reports Positions


```solidity
bytes32 internal constant REPORTS_POSITIONS_SLOT = bytes32(uint256(keccak256("river.state.reportsPositions")) - 1)
```


## Functions
### get

Retrieve the Reports Positions at index


```solidity
function get(uint256 _idx) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_idx`|`uint256`|The index to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if already reported|


### getRaw

Retrieve the raw Reports Positions from storage


```solidity
function getRaw() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Raw Reports Positions|


### register

Register an index as reported


```solidity
function register(uint256 _idx) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_idx`|`uint256`|The index to register|


### clear

Clears all the report positions in storage


```solidity
function clear() internal;
```

