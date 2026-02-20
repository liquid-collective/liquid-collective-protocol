# OracleManagerV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/OracleManager.1.t.sol)

**Inherits:**
Test


## State Variables
### uf

```solidity
UserFactory internal uf = new UserFactory()
```


### oracle

```solidity
address internal oracle
```


### admin

```solidity
address internal admin
```


### oracleManager

```solidity
OracleManagerV1 internal oracleManager
```


### epochsPerFrame

```solidity
uint64 internal constant epochsPerFrame = 225
```


### slotsPerEpoch

```solidity
uint64 internal constant slotsPerEpoch = 32
```


### secondsPerSlot

```solidity
uint64 internal constant secondsPerSlot = 12
```


### genesisTime

```solidity
uint64 internal constant genesisTime = 12345
```


### epochsToAssumedFinality

```solidity
uint64 internal constant epochsToAssumedFinality = 4
```


### annualAprUpperBound

```solidity
uint256 internal constant annualAprUpperBound = 1000
```


### relativeLowerBound

```solidity
uint256 internal constant relativeLowerBound = 250
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testSetOracle


```solidity
function testSetOracle(uint256 _oracleSalt) public;
```

### testSetOracleUnauthorized


```solidity
function testSetOracleUnauthorized(uint256 _oracleSalt) public;
```

### _next


```solidity
function _next(uint256 _salt) internal pure returns (uint256);
```

### testFuzzedReporting


```solidity
function testFuzzedReporting(uint256 _salt) external;
```

### debug_maxIncrease


```solidity
function debug_maxIncrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth, uint256 _timeElapsed)
    internal
    pure
    returns (uint256);
```

### debug_maxDecrease


```solidity
function debug_maxDecrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth)
    internal
    pure
    returns (uint256);
```

### debug_timeBetweenEpochs


```solidity
function debug_timeBetweenEpochs(CLSpec.CLSpecStruct memory cls, uint256 epochPast, uint256 epochNow)
    internal
    pure
    returns (uint256);
```

### testSetCLSpec


```solidity
function testSetCLSpec(
    uint64 _genesisTime,
    uint64 _epochsPerFrame,
    uint64 _slotsPerEpoch,
    uint64 _secondsPerSlot,
    uint64 _epochsToAssumedFinality
) external;
```

### testSetCLSpecUnauthorized


```solidity
function testSetCLSpecUnauthorized(
    uint64 _genesisTime,
    uint64 _epochsPerFrame,
    uint64 _slotsPerEpoch,
    uint64 _secondsPerSlot,
    uint64 _epochsToAssumedFinality
) external;
```

### testSetReportBounds


```solidity
function testSetReportBounds(uint256 upper, uint256 lower) external;
```

### testSetReportBoundsUnauthorized


```solidity
function testSetReportBoundsUnauthorized(uint256 upper, uint256 lower) external;
```

### testExternalViewFunctions


```solidity
function testExternalViewFunctions() external;
```

## Events
### SetOracle

```solidity
event SetOracle(address indexed oracleAddress);
```

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

### Internal_SetReportedStoppedValidatorCounts

```solidity
event Internal_SetReportedStoppedValidatorCounts(uint32[] stoppedValidatorCounts);
```

### SetSpec

```solidity
event SetSpec(
    uint64 epochsPerFrame,
    uint64 slotsPerEpoch,
    uint64 secondsPerSlot,
    uint64 genesisTime,
    uint64 epochsToAssumedFinality
);
```

### SetBounds

```solidity
event SetBounds(uint256 annualAprUpperBound, uint256 relativeLowerBound);
```

## Structs
### ReportingVars

```solidity
struct ReportingVars {
    IOracleManagerV1.ConsensusLayerReport clr;
    CLSpec.CLSpecStruct cls;
    ReportBounds.ReportBoundsStruct rb;
    uint256 depositedValidatorCount;
    uint256 reportedValidatorCount;
    uint256 currentTotalUnderlyingSupply;
    uint256 maxIncrease;
    uint256 elFeesAvailable;
    uint256 exceedingEth;
    uint256 coverageFundAvailable;
}
```

