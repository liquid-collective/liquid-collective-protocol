# SharesPerOwner
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/SharesPerOwner.sol)

**Title:**
Shares Per Owner Storage

Utility to manage the Shares Per Owner in storage


## State Variables
### SHARES_PER_OWNER_SLOT
Storage slot of the Shares Per Owner


```solidity
bytes32 internal constant SHARES_PER_OWNER_SLOT = bytes32(uint256(keccak256("river.state.sharesPerOwner")) - 1)
```


## Functions
### get

Retrieve the share count for given owner


```solidity
function get(address _owner) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The address to get the balance of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of shares|


### set

Set the amount of shares for an owner


```solidity
function set(address _owner, uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The owner of the shares to edit|
|`_newValue`|`uint256`|The new shares value for the owner|


## Structs
### Slot
Structure in storage


```solidity
struct Slot {
    /// @custom:attribute The mapping from an owner to its share count
    mapping(address => uint256) value;
}
```

