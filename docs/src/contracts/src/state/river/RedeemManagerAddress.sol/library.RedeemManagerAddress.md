# RedeemManagerAddress
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/river/RedeemManagerAddress.sol)

**Title:**
Redeem Manager Address Storage

Utility to manage the Redeem Manager Address in storage


## State Variables
### REDEEM_MANAGER_ADDRESS_SLOT
Storage slot of the Redeem Manager Address


```solidity
bytes32 internal constant REDEEM_MANAGER_ADDRESS_SLOT =
    bytes32(uint256(keccak256("river.state.redeemManagerAddress")) - 1)
```


## Functions
### get

Retrieve the Redeem Manager Address


```solidity
function get() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Redeem Manager Address|


### set

Sets the Redeem Manager Address


```solidity
function set(address _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`address`|New Redeem Manager Address|


