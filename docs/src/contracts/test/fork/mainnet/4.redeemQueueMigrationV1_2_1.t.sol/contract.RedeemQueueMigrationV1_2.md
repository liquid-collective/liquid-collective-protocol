# RedeemQueueMigrationV1_2
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/fork/mainnet/4.redeemQueueMigrationV1_2_1.t.sol)

**Inherits:**
Test


## State Variables
### _skip

```solidity
bool internal _skip = false
```


### _rpcUrl

```solidity
string internal _rpcUrl
```


### REDEEM_MANAGER_MAINNET_ADDRESS

```solidity
address internal constant REDEEM_MANAGER_MAINNET_ADDRESS = 0x080b3a41390b357Ad7e8097644d1DEDf57AD3375
```


### REDEEM_MANAGER_MAINNET_PROXY_ADMIN_ADDRESS

```solidity
address internal constant REDEEM_MANAGER_MAINNET_PROXY_ADMIN_ADDRESS = 0x2fDeF0b5e87Cf840FfE46E3A5318b1d59960DfCd
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

### test_migrate_allRedeemRequestsInOneCall


```solidity
function test_migrate_allRedeemRequestsInOneCall() external shouldSkip;
```

