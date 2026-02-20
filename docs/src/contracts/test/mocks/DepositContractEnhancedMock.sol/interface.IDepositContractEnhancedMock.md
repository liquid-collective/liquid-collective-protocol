# IDepositContractEnhancedMock
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/mocks/DepositContractEnhancedMock.sol)


## Functions
### deposit


```solidity
function deposit(
    bytes calldata pubkey,
    bytes calldata withdrawalCredentials,
    bytes calldata signature,
    bytes32 depositDataRoot
) external payable;
```

### get_deposit_root


```solidity
function get_deposit_root() external view returns (bytes32);
```

### get_deposit_count


```solidity
function get_deposit_count() external view returns (bytes memory);
```

## Events
### DepositEvent

```solidity
event DepositEvent(bytes pubkey, bytes withdrawalCredentials, bytes amount, bytes signature, bytes index);
```

