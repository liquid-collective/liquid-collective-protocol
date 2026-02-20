# OracleManagerV1ExposeInitializer
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/OracleManager.1.t.sol)

**Inherits:**
[OracleManagerV1](/contracts/src/components/OracleManager.1.sol/abstract.OracleManagerV1.md)


## State Variables
### amountToRedeem

```solidity
uint256 amountToRedeem
```


### amountToDeposit

```solidity
uint256 amountToDeposit
```


### elFeesAvailable

```solidity
uint256 public elFeesAvailable
```


### coverageFundAvailable

```solidity
uint256 public coverageFundAvailable
```


### redeemDemand

```solidity
uint256 public redeemDemand
```


### exceedingEth

```solidity
uint256 public exceedingEth
```


## Functions
### supersedeReportedBalanceSum


```solidity
function supersedeReportedBalanceSum(uint256 amount) external;
```

### supersedeReportedValidatorCount


```solidity
function supersedeReportedValidatorCount(uint256 amount) external;
```

### supersedeDepositedValidatorCount


```solidity
function supersedeDepositedValidatorCount(uint256 amount) external;
```

### _getRiverAdmin


```solidity
function _getRiverAdmin() internal view override returns (address);
```

### constructor


```solidity
constructor(
    address oracle,
    address admin,
    uint64 epochsPerFrame,
    uint64 slotsPerEpoch,
    uint64 secondsPerSlot,
    uint64 genesisTime,
    uint64 epochsToAssumedFinality,
    uint256 annualAprUpperBound,
    uint256 relativeLowerBound
) ;
```

### _onEarnings


```solidity
function _onEarnings(uint256 amount) internal override;
```

### sudoSetElFeesAvailable


```solidity
function sudoSetElFeesAvailable(uint256 newValue) external;
```

### _pullELFees


```solidity
function _pullELFees(uint256 _max) internal override returns (uint256 result);
```

### sudoSetCoverageFundAvailable


```solidity
function sudoSetCoverageFundAvailable(uint256 newValue) external;
```

### _pullCoverageFunds


```solidity
function _pullCoverageFunds(uint256 _max) internal override returns (uint256 result);
```

### _assetBalance


```solidity
function _assetBalance() internal view override returns (uint256 result);
```

### debug_getTotalUnderlyingBalance


```solidity
function debug_getTotalUnderlyingBalance() external view returns (uint256);
```

### sudoSetRedeemDemand


```solidity
function sudoSetRedeemDemand(uint256 newValue) external;
```

### _reportWithdrawToRedeemManager


```solidity
function _reportWithdrawToRedeemManager() internal override;
```

### _pullCLFunds


```solidity
function _pullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount) internal override;
```

### sudoSetExceedingEth


```solidity
function sudoSetExceedingEth(uint256 newValue) external;
```

### _pullRedeemManagerExceedingEth


```solidity
function _pullRedeemManagerExceedingEth(uint256 max) internal override returns (uint256 result);
```

### _requestExitsBasedOnRedeemDemandAfterRebalancings


```solidity
function _requestExitsBasedOnRedeemDemandAfterRebalancings(
    uint256 exitingBalance,
    uint32[] memory stoppedValidatorCounts,
    bool depositToRedeemRebalancingAllowed,
    bool slashingContainmentModeEnabled
) internal override;
```

### _commitBalanceToDeposit


```solidity
function _commitBalanceToDeposit(uint256 period) internal override;
```

### _skimExcessBalanceToRedeem


```solidity
function _skimExcessBalanceToRedeem() internal override;
```

## Events
### Internal_OnEarnings

```solidity
event Internal_OnEarnings(uint256 amount);
```

### Internal_PullELFees

```solidity
event Internal_PullELFees(uint256 _max, uint256 _returned);
```

### Internal_PullCoverageFunds

```solidity
event Internal_PullCoverageFunds(uint256 _max, uint256 _returned);
```

### Internal_ReportWithdrawToRedeemManager

```solidity
event Internal_ReportWithdrawToRedeemManager(uint256 currentAmountToRedeem);
```

### Internal_PullCLFunds

```solidity
event Internal_PullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount);
```

### Internal_PullRedeemManagerExceedingEth

```solidity
event Internal_PullRedeemManagerExceedingEth(uint256 max, uint256 result);
```

### Internal_SetReportedStoppedValidatorCounts

```solidity
event Internal_SetReportedStoppedValidatorCounts(uint32[] stoppedValidatorCounts);
```

### Internal_RequestExitsBasedOnRedeemDemandAfterRebalancings

```solidity
event Internal_RequestExitsBasedOnRedeemDemandAfterRebalancings(
    uint256 exitingBalance, bool depositToRedeemRebalancingAllowed, uint256 exitCountRequest
);
```

### Internal_CommitBalanceToDeposit

```solidity
event Internal_CommitBalanceToDeposit(uint256 period, uint256 depositBalance);
```

### Internal_SkimExcessBalanceToRedeem

```solidity
event Internal_SkimExcessBalanceToRedeem(uint256 balanceToDeposit, uint256 balanceToRedeem);
```

