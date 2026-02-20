# Allowlist
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/allowlist/Allowlist.sol)

**Title:**
Allowlist Storage

Utility to manage the Allowlist mapping in storage


## State Variables
### ALLOWLIST_SLOT
Storage slot of the Allowlist mapping


```solidity
bytes32 internal constant ALLOWLIST_SLOT = bytes32(uint256(keccak256("river.state.allowlist")) - 1)
```


## Functions
### get

Retrieve the Allowlist value of an account


```solidity
function get(address _account) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The account to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Allowlist value|


### set

Sets the Allowlist value of an account


```solidity
function set(address _account, uint256 _status) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The account value to set|
|`_status`|`uint256`|The value to set|


## Structs
### Slot
Structure stored in storage slot


```solidity
struct Slot {
    /// @custom:attribute Mapping keeping track of permissions per account
    mapping(address => uint256) value;
}
```

