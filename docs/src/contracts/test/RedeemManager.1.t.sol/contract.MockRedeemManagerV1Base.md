# MockRedeemManagerV1Base
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/RedeemManager.1.t.sol)

**Inherits:**
[Initializable](/contracts/src/Initializable.sol/contract.Initializable.md), [IRedeemManagerV1Mock](/contracts/test/RedeemManager.2.t.sol/interface.IRedeemManagerV1Mock.md)


## Functions
### onlyRedeemerOrRiver


```solidity
modifier onlyRedeemerOrRiver() ;
```

### initializeRedeemManagerV1


```solidity
function initializeRedeemManagerV1(address _river) external init(0);
```

### _setRedeemDemand


```solidity
function _setRedeemDemand(uint256 _newValue) internal;
```

### _castedRiver


```solidity
function _castedRiver() internal view returns (IRiverV1);
```

