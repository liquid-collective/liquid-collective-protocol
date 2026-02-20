# LibImplementationUnbricker
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/utils/LibImplementationUnbricker.sol)


## State Variables
### VERSION_SLOT

```solidity
bytes32 public constant VERSION_SLOT = bytes32(uint256(keccak256("river.state.version")) - 1)
```


## Functions
### unbrick


```solidity
function unbrick(Vm vm, address implem) internal;
```

