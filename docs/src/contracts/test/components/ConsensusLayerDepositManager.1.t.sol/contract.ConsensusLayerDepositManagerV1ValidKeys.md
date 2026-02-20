# ConsensusLayerDepositManagerV1ValidKeys
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ConsensusLayerDepositManager.1.t.sol)

**Inherits:**
[ConsensusLayerDepositManagerV1](/contracts/src/components/ConsensusLayerDepositManager.1.sol/abstract.ConsensusLayerDepositManagerV1.md)


## State Variables
### _publicKeys

```solidity
bytes public _publicKeys =
    hex"84B379476E22EE78F2767AECF6D4832E3C3B77BCF068E08A931FEA69C406753378FF1215F0D2077211126A7D7C54F83B"
```


### _signatures

```solidity
bytes public _signatures =
    hex"8A1979CC3E8D2897044AA18F99F78569AFC0EF9CF5CA5F9545070CF2D2A2CCD5C328B2B2280A8BA80CC810A46470BFC80D2EAAC53E533E43BA054A00587027BA0BCBA5FAD22355257CEB96B23E45D5746022312FBB7E7EFA8C3AE17C0713B426"
```


## Functions
### _getRiverAdmin


```solidity
function _getRiverAdmin() internal pure override returns (address);
```

### publicConsensusLayerDepositManagerInitializeV1


```solidity
function publicConsensusLayerDepositManagerInitializeV1(
    address _depositContractAddress,
    bytes32 _withdrawalCredentials
) external;
```

### _getNextValidators


```solidity
function _getNextValidators(IOperatorsRegistryV1.OperatorAllocation[] memory _allocations)
    internal
    view
    override
    returns (bytes[] memory, bytes[] memory);
```

### sudoSetWithdrawalCredentials


```solidity
function sudoSetWithdrawalCredentials(bytes32 _withdrawalCredentials) external;
```

### sudoSyncBalance


```solidity
function sudoSyncBalance() external;
```

### _setCommittedBalance


```solidity
function _setCommittedBalance(uint256 newCommittedBalance) internal override;
```

