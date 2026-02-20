# DepositContractEnhancedMock
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/mocks/DepositContractEnhancedMock.sol)

**Inherits:**
[IDepositContractEnhancedMock](/contracts/test/mocks/DepositContractEnhancedMock.sol/interface.IDepositContractEnhancedMock.md), [ERC165](/contracts/test/mocks/DepositContractEnhancedMock.sol/interface.ERC165.md)


## State Variables
### DEPOSIT_CONTRACT_TREE_DEPTH

```solidity
uint256 public constant DEPOSIT_CONTRACT_TREE_DEPTH = 32
```


### MAX_DEPOSIT_COUNT

```solidity
uint256 public constant MAX_DEPOSIT_COUNT = 2 ** DEPOSIT_CONTRACT_TREE_DEPTH - 1
```


### branch

```solidity
bytes32[DEPOSIT_CONTRACT_TREE_DEPTH] public branch
```


### deposit_count

```solidity
uint256 public deposit_count
```


### zero_hashes

```solidity
bytes32[DEPOSIT_CONTRACT_TREE_DEPTH] public zero_hashes
```


### last_deposit_data_root

```solidity
bytes32 internal last_deposit_data_root
```


## Functions
### constructor


```solidity
constructor() ;
```

### get_deposit_root


```solidity
function get_deposit_root() external view override returns (bytes32);
```

### get_deposit_count


```solidity
function get_deposit_count() external view override returns (bytes memory);
```

### debug_getLastDepositDataRoot


```solidity
function debug_getLastDepositDataRoot() external view returns (bytes32);
```

### deposit


```solidity
function deposit(
    bytes calldata pubkey,
    bytes calldata withdrawal_credentials,
    bytes calldata signature,
    bytes32 deposit_data_root
) external payable override;
```

### supportsInterface


```solidity
function supportsInterface(bytes4 interfaceId) external pure override returns (bool);
```

### to_little_endian_64


```solidity
function to_little_endian_64(uint64 value) internal pure returns (bytes memory ret);
```

