# RedeemQueueV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/redeemManager/RedeemQueue.1.sol)

**Title:**
Redeem Manager Redeem Queue storage

Utility to manage the Redeem Queue in the Redeem Manager


## State Variables
### REDEEM_QUEUE_ID_SLOT
Storage slot of the Redeem Queue


```solidity
bytes32 internal constant REDEEM_QUEUE_ID_SLOT = bytes32(uint256(keccak256("river.state.redeemQueue")) - 1)
```


## Functions
### get

Retrieve the Redeem Queue array storage pointer


```solidity
function get() internal pure returns (RedeemRequest[] storage data);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`data`|`RedeemRequest[]`|The Redeem Queue array storage pointer|


## Structs
### RedeemRequest
The Redeemer structure represents the redeem request made by a user


```solidity
struct RedeemRequest {
    /// @custom:attribute The amount of the redeem request in LsETH
    uint256 amount;
    /// @custom:attribute The maximum amount of ETH redeemable by this request
    uint256 maxRedeemableEth;
    /// @custom:attribute The recipient of the redeem request
    address recipient;
    /// @custom:attribute The height is the cumulative sum of all the sizes of preceding redeem requests
    uint256 height;
}
```

