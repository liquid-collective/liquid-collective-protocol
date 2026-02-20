# BufferedExceedingEth
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/redeemManager/BufferedExceedingEth.sol)

**Title:**
Buffered Exceeding Eth storage

Redeen Manager utility to manage the exceeding ETH with a redeem request


## State Variables
### BUFFERED_EXCEEDING_ETH_SLOT
Storage slot of the Redeem Buffered Eth


```solidity
bytes32 internal constant BUFFERED_EXCEEDING_ETH_SLOT =
    bytes32(uint256(keccak256("river.state.bufferedExceedingEth")) - 1)
```


## Functions
### get

Retrieve the Redeem Buffered Eth Value


```solidity
function get() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Redeem Buffered Eth Value|


### set

Sets the Redeem Buffered Eth Value


```solidity
function set(uint256 newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newValue`|`uint256`|The new value|


