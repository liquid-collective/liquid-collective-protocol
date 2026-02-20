# OperatorsRegistryStrictRiverV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/OperatorsRegistry.1.t.sol)

**Inherits:**
[OperatorsRegistryV1](/contracts/src/OperatorsRegistry.1.sol/contract.OperatorsRegistryV1.md)

Same as OperatorsRegistryInitializableV1 but does NOT override onlyRiver; use for tests that assert Unauthorized


## Functions
### sudoSetFunded


```solidity
function sudoSetFunded(uint256 _index, uint32 _funded) external;
```

### sudoSetKeys


```solidity
function sudoSetKeys(uint256 _operatorIndex, uint32 _keyCount) external;
```

### sudoExitRequests


```solidity
function sudoExitRequests(uint256 _operatorIndex, uint32 _requestedExits) external;
```

### sudoStoppedValidatorCounts


```solidity
function sudoStoppedValidatorCounts(uint32[] calldata stoppedValidatorCount, uint256 depositedValidatorCount)
    external;
```

