# proxy
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/migration/TLC_globalUnlockScheduleMigration.t.sol)


## Functions
### admin


```solidity
function admin() external view returns (address);
```

### upgradeTo


```solidity
function upgradeTo(address newImplementation) external;
```

### upgradeToAndCall


```solidity
function upgradeToAndCall(address newImplementation, bytes calldata cdata) external payable;
```

### migrate


```solidity
function migrate() external;
```

### getVestingScheduleCount


```solidity
function getVestingScheduleCount() external view returns (uint256);
```

### getMigrationCount


```solidity
function getMigrationCount() external view returns (uint256);
```

