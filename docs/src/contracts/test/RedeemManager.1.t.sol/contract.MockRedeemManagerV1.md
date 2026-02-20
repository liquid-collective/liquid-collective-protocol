# MockRedeemManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/RedeemManager.1.t.sol)

**Inherits:**
[MockRedeemManagerV1Base](/contracts/test/RedeemManager.1.t.sol/contract.MockRedeemManagerV1Base.md)


## Functions
### getRedeemRequestDetails


```solidity
function getRedeemRequestDetails(uint32 _redeemRequestId)
    external
    view
    returns (RedeemQueueV1.RedeemRequest memory);
```

### requestRedeem


```solidity
function requestRedeem(uint256 _lsETHAmount, address _recipient)
    external
    onlyRedeemerOrRiver
    returns (uint32 redeemRequestId);
```

### _requestRedeem


```solidity
function _requestRedeem(uint256 _lsETHAmount, address _recipient) internal returns (uint32 redeemRequestId);
```

