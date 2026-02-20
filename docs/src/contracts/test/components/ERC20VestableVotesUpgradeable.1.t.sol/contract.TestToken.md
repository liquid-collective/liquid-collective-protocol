# TestToken
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ERC20VestableVotesUpgradeable.1.t.sol)

**Inherits:**
[ERC20VestableVotesUpgradeableV1](/contracts/src/components/ERC20VestableVotesUpgradeable.1.sol/abstract.ERC20VestableVotesUpgradeableV1.md)


## State Variables
### NAME

```solidity
string internal constant NAME = "Test Token"
```


### SYMBOL

```solidity
string internal constant SYMBOL = "TT"
```


### INITIAL_SUPPLY

```solidity
uint256 internal constant INITIAL_SUPPLY = 1_000_000_000e18
```


## Functions
### initTestTokenV1


```solidity
function initTestTokenV1(address _account) external initializer;
```

### _maxSupply


```solidity
function _maxSupply() internal pure override returns (uint224);
```

### migrateVestingSchedules


```solidity
function migrateVestingSchedules() external reinitializer(2);
```

### debugPushV1VestingSchedule


```solidity
function debugPushV1VestingSchedule(
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

