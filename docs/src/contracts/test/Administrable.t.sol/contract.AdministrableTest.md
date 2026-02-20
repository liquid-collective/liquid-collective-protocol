# AdministrableTest
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/Administrable.t.sol)

**Inherits:**
Test


## State Variables
### wa

```solidity
WithAdmin internal wa
```


### admin

```solidity
address internal admin
```


## Functions
### setUp


```solidity
function setUp() external;
```

### testGetAdmin


```solidity
function testGetAdmin() external;
```

### testProposeAdmin


```solidity
function testProposeAdmin() external;
```

### testProposeAdminUnauthorized


```solidity
function testProposeAdminUnauthorized() external;
```

### testAcceptAdmin


```solidity
function testAcceptAdmin() external;
```

### testAcceptAdminUnauthorized


```solidity
function testAcceptAdminUnauthorized() external;
```

### testCancelTransferAdmin


```solidity
function testCancelTransferAdmin() external;
```

## Events
### SetPendingAdmin

```solidity
event SetPendingAdmin(address indexed pendingAdmin);
```

### SetAdmin

```solidity
event SetAdmin(address indexed admin);
```

