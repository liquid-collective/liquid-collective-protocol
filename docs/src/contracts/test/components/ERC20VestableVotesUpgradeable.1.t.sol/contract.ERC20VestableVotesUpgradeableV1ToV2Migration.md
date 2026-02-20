# ERC20VestableVotesUpgradeableV1ToV2Migration
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ERC20VestableVotesUpgradeable.1.t.sol)

**Inherits:**
Test


## State Variables
### tt

```solidity
TestToken internal tt
```


### escrowImplem

```solidity
address internal escrowImplem
```


### initAccount

```solidity
address internal initAccount
```


### bob

```solidity
address internal bob
```


### joe

```solidity
address internal joe
```


### alice

```solidity
address internal alice
```


## Functions
### setUp


```solidity
function setUp() public;
```

### test_migrateTwice


```solidity
function test_migrateTwice() external;
```

### test_migrateAndInspectVestingSchedules


```solidity
function test_migrateAndInspectVestingSchedules(
    uint64 start,
    uint64 end,
    uint32 cliffDuration,
    uint32 lockDuration,
    uint32 duration,
    uint32 periodDuration,
    uint128 amount,
    address creator,
    address beneficiary,
    bool revocable
) external;
```

