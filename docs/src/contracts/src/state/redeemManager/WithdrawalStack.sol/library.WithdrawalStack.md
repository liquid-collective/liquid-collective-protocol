# WithdrawalStack
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/redeemManager/WithdrawalStack.sol)

**Title:**
Redeem Manager Withdrawal Stack storage

Utility to manage the Withdrawal Stack in the Redeem Manager


## State Variables
### WITHDRAWAL_STACK_ID_SLOT
Storage slot of the Withdrawal Stack


```solidity
bytes32 internal constant WITHDRAWAL_STACK_ID_SLOT = bytes32(uint256(keccak256("river.state.withdrawalStack")) - 1)
```


## Functions
### get

Retrieve the Withdrawal Stack array storage pointer


```solidity
function get() internal pure returns (WithdrawalEvent[] storage data);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`data`|`WithdrawalEvent[]`|The Withdrawal Stack array storage pointer|


## Structs
### WithdrawalEvent
The Redeemer structure represents the withdrawal events made by River


```solidity
struct WithdrawalEvent {
    /// @custom:attribute The amount of the withdrawal event in LsETH
    uint256 amount;
    /// @custom:attribute The amount of the withdrawal event in ETH
    uint256 withdrawnEth;
    /// @custom:attribute The height is the cumulative sum of all the sizes of preceding withdrawal events
    uint256 height;
}
```

