# RedeemQueueMigrationV1_2
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/fork/holesky/1.redeemQueueMigrationV1_2_1.t.sol)

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


### REDEEM_MANAGER_STAGING_ADDRESS

```solidity
address internal constant REDEEM_MANAGER_STAGING_ADDRESS = 0x0693875efbF04dDAd955c04332bA3324472DF980
```


### REDEEM_MANAGER_STAGING_PROXY_ADMIN_ADDRESS

```solidity
address internal constant REDEEM_MANAGER_STAGING_PROXY_ADMIN_ADDRESS = 0x80Cf8bD4abf6C078C313f72588720AB86d45c5E6
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

