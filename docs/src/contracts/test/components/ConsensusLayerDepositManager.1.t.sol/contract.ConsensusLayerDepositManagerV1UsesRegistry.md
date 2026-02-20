# ConsensusLayerDepositManagerV1UsesRegistry
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ConsensusLayerDepositManager.1.t.sol)

**Inherits:**
[ConsensusLayerDepositManagerV1](/contracts/src/components/ConsensusLayerDepositManager.1.sol/abstract.ConsensusLayerDepositManagerV1.md)

Deposit manager test double that delegates _getNextValidators to the real OperatorsRegistry (same as River in production)


## State Variables
### registry

```solidity
IOperatorsRegistryV1 public registry
```


## Functions
### _getRiverAdmin


```solidity
function _getRiverAdmin() internal pure override returns (address);
```

### setRegistry


```solidity
function setRegistry(IOperatorsRegistryV1 _registry) external;
```

### publicConsensusLayerDepositManagerInitializeV1


```solidity
function publicConsensusLayerDepositManagerInitializeV1(
    address _depositContractAddress,
    bytes32 _withdrawalCredentials
) external;
```

### setKeeper


```solidity
function setKeeper(address _keeper) external;
```

### _getNextValidators


```solidity
function _getNextValidators(IOperatorsRegistryV1.OperatorAllocation[] memory _allocations)
    internal
    override
    returns (bytes[] memory publicKeys, bytes[] memory signatures);
```

### sudoSyncBalance


```solidity
function sudoSyncBalance() external;
```

### _setCommittedBalance


```solidity
function _setCommittedBalance(uint256 newCommittedBalance) internal override;
```

