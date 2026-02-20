# FirewallTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/Firewall.t.sol)

**Inherits:**
[BytesGenerator](/contracts/test/utils/BytesGenerator.sol/contract.BytesGenerator.md), [OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md)


## State Variables
### allowlist

```solidity
AllowlistV1 internal allowlist
```


### elFeeRecipient

```solidity
ELFeeRecipientV1 internal elFeeRecipient
```


### deposit

```solidity
IDepositContract internal deposit
```


### withdraw

```solidity
WithdrawV1 internal withdraw
```


### proxyUpgraderDAO

```solidity
address internal proxyUpgraderDAO = address(0x484bCd65393c9E835a245Bfa3a299FA02fD1cb18)
```


### riverGovernorDAO

```solidity
address internal riverGovernorDAO = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8)
```


### executor

```solidity
address internal executor = address(0xa22c003A45554Ce90E7F97a3f613F16905440468)
```


### bob

```solidity
address internal bob = address(0x34b4424f81AF11f8B8c261b339dd27e1Da796f11)
```


### joe

```solidity
address internal joe = address(0xA7206d878c5c3871826DfdB42191c49B1D11F466)
```


### don

```solidity
address internal don = address(0xc99b2dBB74607A04B458Ea740F3906C4851C6531)
```


### collector

```solidity
address internal collector = address(0xC88F7666330b4b511358b7742dC2a3234710e7B1)
```


### river

```solidity
RiverV1 internal river
```


### oracle

```solidity
OracleV1 internal oracle
```


### oracleFirewall

```solidity
Firewall internal oracleFirewall
```


### firewalledOracle

```solidity
OracleV1 internal firewalledOracle
```


### oracleInput

```solidity
IRiverV1 internal oracleInput
```


### firewalledAllowlist

```solidity
AllowlistV1 internal firewalledAllowlist
```


### allowlistFirewall

```solidity
Firewall internal allowlistFirewall
```


### firewalledRiver

```solidity
RiverV1 internal firewalledRiver
```


### riverFirewall

```solidity
Firewall internal riverFirewall
```


### firewalledOperatorsRegistry

```solidity
OperatorsRegistryV1 internal firewalledOperatorsRegistry
```


### operatorsRegistryFirewall

```solidity
Firewall internal operatorsRegistryFirewall
```


### operatorsRegistry

```solidity
OperatorsRegistryV1 internal operatorsRegistry
```


### EPOCHS_PER_FRAME

```solidity
uint64 internal constant EPOCHS_PER_FRAME = 225
```


### SLOTS_PER_EPOCH

```solidity
uint64 internal constant SLOTS_PER_EPOCH = 32
```


### SECONDS_PER_SLOT

```solidity
uint64 internal constant SECONDS_PER_SLOT = 12
```


### GENESIS_TIME

```solidity
uint64 internal constant GENESIS_TIME = 1606824023
```


### UPPER_BOUND

```solidity
uint256 internal constant UPPER_BOUND = 1000
```


### LOWER_BOUND

```solidity
uint256 internal constant LOWER_BOUND = 500
```


### unauthJoe

```solidity
bytes internal unauthJoe = abi.encodeWithSignature("Unauthorized(address)", joe)
```


### unauthExecutor

```solidity
bytes internal unauthExecutor = abi.encodeWithSignature("Unauthorized(address)", executor)
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testGovernorCanAddOperator


```solidity
function testGovernorCanAddOperator() public;
```

### testExecutorCannotAddOperator


```solidity
function testExecutorCannotAddOperator() public;
```

### testRandomCallerCannotAddOperator


```solidity
function testRandomCallerCannotAddOperator() public;
```

### testGovernorCanSetGlobalFee


```solidity
function testGovernorCanSetGlobalFee() public;
```

### testExecutorCannotSetGlobalFee


```solidity
function testExecutorCannotSetGlobalFee() public;
```

### testRandomCallerCannotSetGlobalFee


```solidity
function testRandomCallerCannotSetGlobalFee() public;
```

### testGovernorCanSetAllower


```solidity
function testGovernorCanSetAllower() public;
```

### testExecutorCannotSetAllower


```solidity
function testExecutorCannotSetAllower() public;
```

### testRandomCallerCannotSetAllower


```solidity
function testRandomCallerCannotSetAllower() public;
```

### haveGovernorAddOperatorBob


```solidity
function haveGovernorAddOperatorBob() public returns (uint256 operatorBobIndex);
```

### testGovernorCanSetOperatorStatus


```solidity
function testGovernorCanSetOperatorStatus() public;
```

### testExecutorCanSetOperatorStatus


```solidity
function testExecutorCanSetOperatorStatus() public;
```

### testRandomCallerCannotSetOperatorStatus


```solidity
function testRandomCallerCannotSetOperatorStatus() public;
```

### testGovernorCanSetOperatorLimit


```solidity
function testGovernorCanSetOperatorLimit() public;
```

### testExecutorCanSetOperatorLimit


```solidity
function testExecutorCanSetOperatorLimit() public;
```

### testRandomCallerCannotSetOperatorLimit


```solidity
function testRandomCallerCannotSetOperatorLimit() public;
```

### testGovernorCannotdepositToConsensusLayerWithDepositRoot


```solidity
function testGovernorCannotdepositToConsensusLayerWithDepositRoot() public;
```

### testExecutorCannotdepositToConsensusLayerWithDepositRoot


```solidity
function testExecutorCannotdepositToConsensusLayerWithDepositRoot() public;
```

### testRandomCallerCannotdepositToConsensusLayerWithDepositRoot


```solidity
function testRandomCallerCannotdepositToConsensusLayerWithDepositRoot() public;
```

### testGovernorCanSetOracle


```solidity
function testGovernorCanSetOracle() public;
```

### testExecutorCanSetOracle


```solidity
function testExecutorCanSetOracle() public;
```

### testRandomCallerCannotSetOracle


```solidity
function testRandomCallerCannotSetOracle() public;
```

### testGovernorCanAddMember


```solidity
function testGovernorCanAddMember() public;
```

### testGovernorCanRemoveMember


```solidity
function testGovernorCanRemoveMember() public;
```

### testExecutorCanAddMember


```solidity
function testExecutorCanAddMember() public;
```

### testExecutorCanRemoveMember


```solidity
function testExecutorCanRemoveMember() public;
```

### testRandomCallerCannotAddMember


```solidity
function testRandomCallerCannotAddMember() public;
```

### testRandomCallerCannotRemoveMember


```solidity
function testRandomCallerCannotRemoveMember() public;
```

### testGovernorCanSetQuorum


```solidity
function testGovernorCanSetQuorum() public;
```

### testExecutorCanSetQuorum


```solidity
function testExecutorCanSetQuorum() public;
```

### testRandomCallerCannotSetQuorum


```solidity
function testRandomCallerCannotSetQuorum() public;
```

### getSelector

convert function sig, of form "functionName(arg1Type,arg2Type)", to the 4 bytes used in
a contract call, accessible at msg.sig


```solidity
function getSelector(string memory functionSig) internal pure returns (bytes4);
```

### testMakingFunctionGovernorOnly


```solidity
function testMakingFunctionGovernorOnly() public;
```

### testMakingFunctionGovernorOrExecutor


```solidity
function testMakingFunctionGovernorOrExecutor() public;
```

### testExecutorCannotChangePermissions


```solidity
function testExecutorCannotChangePermissions() public;
```

### testRandomCallerCannotChangePermissions


```solidity
function testRandomCallerCannotChangePermissions() public;
```

### testGovernorCanChangeExecutor


```solidity
function testGovernorCanChangeExecutor() public;
```

### testExecutorCanChangeExecutor


```solidity
function testExecutorCanChangeExecutor() public;
```

### testRandomCallerCannotChangeExecutor


```solidity
function testRandomCallerCannotChangeExecutor() public;
```

### testVersion


```solidity
function testVersion() external;
```

## Events
### SetExecutor

```solidity
event SetExecutor(address indexed executor);
```

### SetDestination

```solidity
event SetDestination(address indexed destination);
```

### SetExecutorPermissions

```solidity
event SetExecutorPermissions(bytes4 selector, bool status);
```

