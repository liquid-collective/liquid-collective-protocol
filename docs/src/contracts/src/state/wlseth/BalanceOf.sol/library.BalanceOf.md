# BalanceOf
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/wlseth/BalanceOf.sol)

**Title:**
Balance Storage

Utility to manage the Balance in storage


## State Variables
### BALANCE_OF_SLOT
Storage slot of the Balance


```solidity
bytes32 internal constant BALANCE_OF_SLOT = bytes32(uint256(keccak256("river.state.balanceOf")) - 1)
```


## Functions
### get

Retrieve balance of an owner


```solidity
function get(address _owner) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The owner of the balance|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of the owner|


### set

Set the balance of an owner


```solidity
function set(address _owner, uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The owner to change the balance of|
|`_newValue`|`uint256`|New balance value for the owner|


## Structs
### Slot
The structure in storage


```solidity
struct Slot {
    /// @custom:attribute The mapping from an owner to its balance
    mapping(address => uint256) value;
}
```

