# OperatorAllocationTestBase
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/OperatorAllocationTestBase.sol)

**Inherits:**
Test


## Functions
### _createAllocation


```solidity
function _createAllocation(uint256 count) internal pure returns (IOperatorsRegistryV1.OperatorAllocation[] memory);
```

### _createAllocation


```solidity
function _createAllocation(uint256 operatorIndex, uint256 count)
    internal
    pure
    returns (IOperatorsRegistryV1.OperatorAllocation[] memory);
```

### _createAllocation


```solidity
function _createAllocation(uint256[] memory opIndexes, uint32[] memory counts)
    internal
    pure
    returns (IOperatorsRegistryV1.OperatorAllocation[] memory);
```

### _createMultiAllocation


```solidity
function _createMultiAllocation(uint256[] memory opIndexes, uint32[] memory counts)
    internal
    pure
    virtual
    returns (IOperatorsRegistryV1.OperatorAllocation[] memory);
```

