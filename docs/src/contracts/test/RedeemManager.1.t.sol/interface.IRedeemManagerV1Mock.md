# IRedeemManagerV1Mock
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/RedeemManager.1.t.sol)


## Events
### RequestedRedeem

```solidity
event RequestedRedeem(
    address indexed recipient, uint256 height, uint256 amount, uint256 maxRedeemableEth, uint32 id
);
```

### SetRedeemDemand

```solidity
event SetRedeemDemand(uint256 oldRedeemDemand, uint256 newRedeemDemand);
```

### SetRiver

```solidity
event SetRiver(address river);
```

## Errors
### InvalidZeroAmount
Thrown When a zero value is provided


```solidity
error InvalidZeroAmount();
```

### TransferError
Thrown when a transfer error occured with LsETH


```solidity
error TransferError();
```

### IncompatibleArrayLengths
Thrown when the provided arrays don't have matching lengths


```solidity
error IncompatibleArrayLengths();
```

### RedeemRequestOutOfBounds

```solidity
error RedeemRequestOutOfBounds(uint256 id);
```

### DoesNotMatch

```solidity
error DoesNotMatch(uint256 redeemRequestId, uint256 withdrawalEventId);
```

### RecipientIsDenied
Thrown when the recipient of redeemRequest is denied


```solidity
error RecipientIsDenied();
```

