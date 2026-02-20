# RiverV1TestBase
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/River.1.t.sol)

**Inherits:**
[OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md), [BytesGenerator](/contracts/test/utils/BytesGenerator.sol/contract.BytesGenerator.md)


## State Variables
### uf

```solidity
UserFactory internal uf = new UserFactory()
```


### river

```solidity
RiverV1ForceCommittable internal river
```


### deposit

```solidity
IDepositContract internal deposit
```


### withdraw

```solidity
WithdrawV1 internal withdraw
```


### oracle

```solidity
OracleV1 internal oracle
```


### elFeeRecipient

```solidity
ELFeeRecipientV1 internal elFeeRecipient
```


### coverageFund

```solidity
CoverageFundV1 internal coverageFund
```


### allowlist

```solidity
AllowlistV1 internal allowlist
```


### operatorsRegistry

```solidity
OperatorsRegistryWithOverridesV1 internal operatorsRegistry
```


### admin

```solidity
address internal admin
```


### newAdmin

```solidity
address internal newAdmin
```


### denier

```solidity
address internal denier
```


### collector

```solidity
address internal collector
```


### newCollector

```solidity
address internal newCollector
```


### allower

```solidity
address internal allower
```


### oracleMember

```solidity
address internal oracleMember
```


### newAllowlist

```solidity
address internal newAllowlist
```


### operatorOne

```solidity
address internal operatorOne
```


### operatorOneFeeRecipient

```solidity
address internal operatorOneFeeRecipient
```


### operatorTwo

```solidity
address internal operatorTwo
```


### operatorTwoFeeRecipient

```solidity
address internal operatorTwoFeeRecipient
```


### bob

```solidity
address internal bob
```


### joe

```solidity
address internal joe
```


### operatorOneName

```solidity
string internal operatorOneName = "NodeMasters"
```


### operatorTwoName

```solidity
string internal operatorTwoName = "StakePros"
```


### operatorOneIndex

```solidity
uint256 internal operatorOneIndex
```


### operatorTwoIndex

```solidity
uint256 internal operatorTwoIndex
```


### epochsPerFrame

```solidity
uint64 constant epochsPerFrame = 225
```


### slotsPerEpoch

```solidity
uint64 constant slotsPerEpoch = 32
```


### secondsPerSlot

```solidity
uint64 constant secondsPerSlot = 12
```


### epochsUntilFinal

```solidity
uint64 constant epochsUntilFinal = 4
```


### maxDailyNetCommittableAmount

```solidity
uint128 constant maxDailyNetCommittableAmount = 3200 ether
```


### maxDailyRelativeCommittableAmount

```solidity
uint128 constant maxDailyRelativeCommittableAmount = 2000
```


## Functions
### _createMultiAllocation


```solidity
function _createMultiAllocation(uint256[] memory opIndexes, uint32[] memory counts)
    internal
    pure
    override
    returns (IOperatorsRegistryV1.OperatorAllocation[] memory);
```

### setUp


```solidity
function setUp() public virtual;
```

## Events
### PulledELFees

```solidity
event PulledELFees(uint256 amount);
```

### SetELFeeRecipient

```solidity
event SetELFeeRecipient(address indexed elFeeRecipient);
```

### SetCollector

```solidity
event SetCollector(address indexed collector);
```

### SetCoverageFund

```solidity
event SetCoverageFund(address indexed coverageFund);
```

### SetAllowlist

```solidity
event SetAllowlist(address indexed allowlist);
```

### SetGlobalFee

```solidity
event SetGlobalFee(uint256 fee);
```

### SetOperatorsRegistry

```solidity
event SetOperatorsRegistry(address indexed operatorsRegistry);
```

