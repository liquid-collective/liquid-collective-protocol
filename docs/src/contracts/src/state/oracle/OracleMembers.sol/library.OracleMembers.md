# OracleMembers
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/oracle/OracleMembers.sol)

**Title:**
Oracle Members Storage

Utility to manage the Oracle Members in storage

There can only be up to 256 oracle members. This is due to how report statuses are stored in Reports Positions


## State Variables
### ORACLE_MEMBERS_SLOT
Storage slot of the Oracle Members


```solidity
bytes32 internal constant ORACLE_MEMBERS_SLOT = bytes32(uint256(keccak256("river.state.oracleMembers")) - 1)
```


## Functions
### get

Retrieve the list of oracle members


```solidity
function get() internal view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|List of oracle members|


### push

Add a new oracle member to the list


```solidity
function push(address _newOracleMember) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newOracleMember`|`address`|Address of the new oracle member|


### set

Set an address in the oracle member list


```solidity
function set(uint256 _index, address _newOracleAddress) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|The index to edit|
|`_newOracleAddress`|`address`|The new value of the oracle member|


### indexOf

Retrieve the index of the oracle member


```solidity
function indexOf(address _memberAddress) internal view returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The address to lookup|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The index of the member, -1 if not found|


### deleteItem

Delete the oracle member at the given index


```solidity
function deleteItem(uint256 _idx) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_idx`|`uint256`|The index of the member to remove|


## Structs
### Slot
The structure in storage


```solidity
struct Slot {
    /// @custom:attribute The array of oracle members
    address[] value;
}
```

