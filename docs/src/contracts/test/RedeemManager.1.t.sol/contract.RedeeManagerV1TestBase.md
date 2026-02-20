# RedeeManagerV1TestBase
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/RedeemManager.1.t.sol)

**Inherits:**
Test


## State Variables
### allowlist

```solidity
AllowlistV1 internal allowlist
```


### river

```solidity
RiverMock internal river
```


### uf

```solidity
UserFactory internal uf = new UserFactory()
```


### allowlistAdmin

```solidity
address internal allowlistAdmin
```


### allowlistAllower

```solidity
address internal allowlistAllower
```


### allowlistDenier

```solidity
address internal allowlistDenier
```


### mockRiverAddress

```solidity
address public mockRiverAddress
```


### REDEEM_QUEUE_ID_SLOT

```solidity
bytes32 internal constant REDEEM_QUEUE_ID_SLOT = bytes32(uint256(keccak256("river.state.redeemQueue")) - 1)
```


## Events
### RequestedRedeem

```solidity
event RequestedRedeem(address indexed recipient, uint256 height, uint256 size, uint256 maxRedeemableEth, uint32 id);
```

### ReportedWithdrawal

```solidity
event ReportedWithdrawal(uint256 height, uint256 size, uint256 ethAmount, uint32 id);
```

### SatisfiedRedeemRequest

```solidity
event SatisfiedRedeemRequest(
    uint32 indexed redeemRequestId,
    uint32 indexed withdrawalEventId,
    uint256 lsEthAmountSatisfied,
    uint256 ethAmountSatisfied,
    uint256 lsEthAmountRemaining,
    uint256 ethAmountExceeding
);
```

### ClaimedRedeemRequest

```solidity
event ClaimedRedeemRequest(
    uint32 indexed redeemRequestId,
    address indexed recipient,
    uint256 ethAmount,
    uint256 lsEthAmount,
    uint256 remainingLsEthAmount
);
```

