# InitializeRedeemManagerV1_2Test
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/RedeemManager.1.t.sol)

**Inherits:**
[RedeeManagerV1TestBase](/contracts/test/RedeemManager.1.t.sol/contract.RedeeManagerV1TestBase.md)


## State Variables
### admin

```solidity
address public admin = address(0x123)
```


### redeemManager

```solidity
address redeemManager
```


### REDEEM_QUEUE_V1_SLOT

```solidity
bytes32 constant REDEEM_QUEUE_V1_SLOT = bytes32(uint256(keccak256("river.state.redeemQueue")) - 1)
```


### INITIALIZABLE_STORAGE_SLOT

```solidity
bytes32 constant INITIALIZABLE_STORAGE_SLOT = bytes32(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)
```


### IMPLEMENTATION_SLOT

```solidity
bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```


## Functions
### _allowlistUser


```solidity
function _allowlistUser(address user) internal;
```

### setUp


```solidity
function setUp() public;
```

### testInitializeTwice


```solidity
function testInitializeTwice() public;
```

### testRedeemQueueMigrationV1_2


```solidity
function testRedeemQueueMigrationV1_2() public;
```

### testRedeemQueueV1_2PostMigrationWithNewRequests


```solidity
function testRedeemQueueV1_2PostMigrationWithNewRequests() public;
```

