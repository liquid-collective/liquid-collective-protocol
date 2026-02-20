# DepositContractInvalidMock
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/mocks/DepositContractInvalidMock.sol)

**Inherits:**
[IDepositContract](/contracts/src/interfaces/IDepositContract.sol/interface.IDepositContract.md), Test


## State Variables
### counter

```solidity
uint256 internal counter
```


## Functions
### get_deposit_root


```solidity
function get_deposit_root() external view returns (bytes32);
```

### to_little_endian_64


```solidity
function to_little_endian_64(uint64 value) internal pure returns (bytes memory ret);
```

### deposit


```solidity
function deposit(bytes calldata pubkey, bytes calldata withdrawalCredentials, bytes calldata signature, bytes32)
    external
    payable;
```

## Events
### DepositEvent

```solidity
event DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index);
```

