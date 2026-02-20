# TUPProxyTest
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/TUPProxy.t.sol)

**Inherits:**
Test


## State Variables
### implem

```solidity
DummyCounter internal implem
```


### implemEvolved

```solidity
DummyCounterEvolved internal implemEvolved
```


### proxy

```solidity
TUPProxy internal proxy
```


### admin

```solidity
address internal admin
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testViewFunc


```solidity
function testViewFunc() public view;
```

### testFunc


```solidity
function testFunc() public;
```

### testFuncAsAdmin


```solidity
function testFuncAsAdmin() public;
```

### testRevert


```solidity
function testRevert() public;
```

### testUpgradeToAndCall


```solidity
function testUpgradeToAndCall() public;
```

### testPause


```solidity
function testPause() public;
```

### testUnPause


```solidity
function testUnPause() public;
```

### testPauseAddressZeroFallback


```solidity
function testPauseAddressZeroFallback() public;
```

## Events
### Paused

```solidity
event Paused(address admin);
```

### Unpaused

```solidity
event Unpaused(address admin);
```

