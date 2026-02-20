# OracleV1TestBase
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/Oracle.1.t.sol)

**Inherits:**
Test


## State Variables
### oracle

```solidity
OracleV1 internal oracle
```


### oracleInput

```solidity
IRiverV1 internal oracleInput
```


### uf

```solidity
UserFactory internal uf = new UserFactory()
```


### admin

```solidity
address internal admin = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8)
```


### oracleOne

```solidity
address internal oracleOne = address(0x7fe52bbF4D779cA115231b604637d5f80bab2C40)
```


### oracleTwo

```solidity
address internal oracleTwo = address(0xb479DE67E0827Cc72bf5c1727e3bf6fe15007554)
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


## Functions
### setUp


```solidity
function setUp() public virtual;
```

## Events
### SetQuorum

```solidity
event SetQuorum(uint256 _newQuorum);
```

### AddMember

```solidity
event AddMember(address indexed member);
```

### RemoveMember

```solidity
event RemoveMember(address indexed member);
```

### SetMember

```solidity
event SetMember(address indexed oldAddress, address indexed newAddress);
```

### SetSpec

```solidity
event SetSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime);
```

### SetBounds

```solidity
event SetBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound);
```

### SetRiver

```solidity
event SetRiver(address _river);
```

