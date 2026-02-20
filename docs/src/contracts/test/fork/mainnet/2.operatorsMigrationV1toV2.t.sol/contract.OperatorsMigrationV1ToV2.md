# OperatorsMigrationV1ToV2
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/fork/mainnet/2.operatorsMigrationV1toV2.t.sol)

**Inherits:**
Test


## State Variables
### _skip

```solidity
bool internal _skip = false
```


### OPERATORS_REGISTRY_MAINNET_ADDRESS

```solidity
address internal constant OPERATORS_REGISTRY_MAINNET_ADDRESS = 0x1235f1b60df026B2620e48E735C422425E06b725
```


### OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS

```solidity
address internal constant OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS =
    0x1d1FD2d8C87Fed864708bbab84c2Da54254F5a12
```


## Functions
### setUp


```solidity
function setUp() external;
```

### shouldSkip


```solidity
modifier shouldSkip() ;
```

### test_migration


```solidity
function test_migration() external shouldSkip;
```

