# TlcMigrationTest
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/migration/TLC_globalUnlockScheduleMigration.t.sol)

**Inherits:**
Test


## State Variables
### migrationsContract

```solidity
TlcMigration migrationsContract
```


### tlc

```solidity
TLCV1 tlc
```


### rpc

```solidity
string rpc = "https://mainnet.infura.io/v3/285952fdf94740b6b5b2c551accab0c9"
```


### newLockDuration

```solidity
uint32[] newLockDuration = [
    140140800,
    140140800,
    140140800,
    140140800,
    140140800,
    140140800,
    140140800,
    134697600,
    129859200,
    136771200,
    136771200,
    136771200,
    136771200,
    131414400,
    120873600,
    122601600,
    122342400,
    118108800,
    140140800,
    113842800,
    140140800,
    113842800,
    140140800,
    113842800,
    140140800,
    140140800,
    140140800,
    134697600,
    114739200,
    114739200,
    115084800,
    115171200,
    115257600,
    115084800,
    115257600,
    115257600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    107229600,
    105321600,
    113097600,
    106012800,
    111369600,
    109382400,
    102556800,
    107229600,
    107229600,
    107229600,
    95299200,
    96508800,
    96249600,
    101347200,
    101433600,
    100224000,
    99014400,
    96595200,
    95990400,
    95990400,
    90892800,
    90460800,
    90460800,
    89337600,
    88646400,
    85622400,
    88732800,
    87177600,
    84499200,
    87177600,
    114652800,
    114652800,
    85708800,
    87177600,
    105667200,
    81475200,
    80870400,
    79488000,
    79488000,
    74822400,
    73612800,
    78451200,
    68515200
]
```


### isGlobalUnlockedScheduleIgnoredOld

```solidity
bool[] isGlobalUnlockedScheduleIgnoredOld
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testCreate


```solidity
function testCreate() public;
```

### testGas


```solidity
function testGas() public;
```

### testMigrate


```solidity
function testMigrate() public;
```

