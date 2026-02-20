# RedeemDemand
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/redeemManager/RedeemDemand.sol)

**Title:**
Redeem Demand storage

Redeem Manager utility to store the current demand in LsETH


## State Variables
### REDEEM_DEMAND_SLOT
Storage slot of the Redeem Demand


```solidity
bytes32 internal constant REDEEM_DEMAND_SLOT = bytes32(uint256(keccak256("river.state.redeemDemand")) - 1)
```


## Functions
### get

Retrieve the Redeem Demand Value


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Redeem Demand Value|


### set

Sets the Redeem Demand Value


```solidity
function set(uint256 newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newValue`|`uint256`|The new value|


