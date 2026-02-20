# ITLCV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/ITLC.1.sol)

**Inherits:**
IERC20Upgradeable, IVotesUpgradeable, [IERC20VestableVotesUpgradeableV1](/contracts/src/interfaces/components/IERC20VestableVotesUpgradeable.1.sol/interface.IERC20VestableVotesUpgradeableV1.md)

**Title:**
TLC Interface (v1)

**Author:**
Alluvial Finance Inc.

TLC token interface


## Functions
### initTLCV1

Initializes the TLC Token


```solidity
function initTLCV1(address _account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The initial account to grant all the minted tokens|


### migrateVestingSchedules

Migrates the vesting schedule state structures


```solidity
function migrateVestingSchedules() external;
```

