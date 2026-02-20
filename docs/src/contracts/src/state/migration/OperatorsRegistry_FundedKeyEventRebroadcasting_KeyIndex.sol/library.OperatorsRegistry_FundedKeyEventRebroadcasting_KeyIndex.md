# OperatorsRegistry_FundedKeyEventRebroadcasting_KeyIndex
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/migration/OperatorsRegistry_FundedKeyEventRebroadcasting_KeyIndex.sol)


## State Variables
### KEY_INDEX_SLOT

```solidity
bytes32 internal constant KEY_INDEX_SLOT = bytes32(
    uint256(keccak256("river.state.migration.operatorsRegistry.fundedKeyEventRebroadcasting.keyIndex")) - 1
)
```


## Functions
### get


```solidity
function get() internal view returns (uint256);
```

### set


```solidity
function set(uint256 _newValue) internal;
```

