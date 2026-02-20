# ApprovalsPerOwner
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/shared/ApprovalsPerOwner.sol)

**Title:**
Approvals Per Owner Storage

Utility to manage the Approvals Per Owner in storage


## State Variables
### APPROVALS_PER_OWNER_SLOT
Storage slot of the Approvals Per Owner


```solidity
bytes32 internal constant APPROVALS_PER_OWNER_SLOT =
    bytes32(uint256(keccak256("river.state.approvalsPerOwner")) - 1)
```


## Functions
### get

Retrieve the approval for an owner to an operator


```solidity
function get(address _owner, address _operator) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The account that gave the approval|
|`_operator`|`address`|The account receiving the approval|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The value of the approval|


### set

Set the approval value for an owner to an operator


```solidity
function set(address _owner, address _operator, uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The account that gives the approval|
|`_operator`|`address`|The account receiving the approval|
|`_newValue`|`uint256`|The value of the approval|


## Structs
### Slot
The structure in storage


```solidity
struct Slot {
    /// @custom:attribute The mapping from an owner to an operator to the approval amount
    mapping(address => mapping(address => uint256)) value;
}
```

