# TLCV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/TLC.1.sol)

**Inherits:**
[ITLCV1](/contracts/src/interfaces/ITLC.1.sol/interface.ITLCV1.md), [ERC20VestableVotesUpgradeableV1](/contracts/src/components/ERC20VestableVotesUpgradeable.1.sol/abstract.ERC20VestableVotesUpgradeableV1.md)

**Title:**
TLC (v1)

**Author:**
Alluvial Finance Inc.

The TLC token has a max supply of 1,000,000,000 and 18 decimal places.

Upon deployment, all minted tokens are send to account provided at construction, in charge of creating the vesting schedules

The contract is based on ERC20Votes by OpenZeppelin. Users need to delegate their voting power to someone or themselves to be able to vote.

The contract contains vesting logics allowing vested users to still be able to delegate their voting power while their tokens are held in an escrow


## State Variables
### NAME

```solidity
string internal constant NAME = "Liquid Collective"
```


### SYMBOL

```solidity
string internal constant SYMBOL = "TLC"
```


### INITIAL_SUPPLY

```solidity
uint256 internal constant INITIAL_SUPPLY = 1_000_000_000e18
```


## Functions
### constructor

Disables implementation initialization


```solidity
constructor() ;
```

### initTLCV1

Initializes the TLC Token


```solidity
function initTLCV1(address _account) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The initial account to grant all the minted tokens|


### migrateVestingSchedules

Migrates the vesting schedule state structures


```solidity
function migrateVestingSchedules() external reinitializer(2);
```

