# AllowlistV1Tests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/Allowlist.1.t.sol)

**Inherits:**
[AllowlistV1TestBase](/contracts/test/Allowlist.1.t.sol/abstract.AllowlistV1TestBase.md)


## State Variables
### TEST_ONE_MASK

```solidity
uint256 internal constant TEST_ONE_MASK = 0x1
```


### TEST_TWO_MASK

```solidity
uint256 internal constant TEST_TWO_MASK = 0x1 << 1
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testSetAllowlistStatus


```solidity
function testSetAllowlistStatus(uint256 userSalt) public;
```

### testSetAllowlistStatus


```solidity
function testSetAllowlistStatus() public;
```

### testSetAllowlistStatusZeroAddress


```solidity
function testSetAllowlistStatusZeroAddress() public;
```

### testSetAllowlistStatusComplicatedMask


```solidity
function testSetAllowlistStatusComplicatedMask(uint256 userOneSalt, uint256 userTwoSalt) public;
```

### testSetAllowlistStatusUnauthorized


```solidity
function testSetAllowlistStatusUnauthorized(uint256 userSalt) public;
```

### testSetDenylistStatusUnauthorized


```solidity
function testSetDenylistStatusUnauthorized(uint256 userSalt) public;
```

### testSetAllowlistStatusMultipleSame


```solidity
function testSetAllowlistStatusMultipleSame(uint256 userOneSalt, uint256 userTwoSalt, uint256 userThreeSalt)
    public;
```

### testSetAllowlistStatusMultipleDifferent


```solidity
function testSetAllowlistStatusMultipleDifferent(uint256 userOneSalt, uint256 userTwoSalt, uint256 userThreeSalt)
    public;
```

### testSetAllowlistRevertForMismatch


```solidity
function testSetAllowlistRevertForMismatch(uint256 userOneSalt, uint256 userTwoSalt, uint256 userThreeSalt) public;
```

### testSetAllower


```solidity
function testSetAllower(uint256 adminSalt, uint256 newAllowerSalt) public;
```

### testSetAllowerUnauthorized


```solidity
function testSetAllowerUnauthorized(uint256 nonAdminSalt, uint256 newAllowerSalt) public;
```

### testSetDenier


```solidity
function testSetDenier(uint256 adminSalt, uint256 newDenierSalt) public;
```

### testSetDenierUnauthorized


```solidity
function testSetDenierUnauthorized(uint256 nonAdminSalt, uint256 newDenierSalt) public;
```

### testSetUserDenied


```solidity
function testSetUserDenied(uint256 userSalt) public;
```

### testUnauthorizedPermission


```solidity
function testUnauthorizedPermission(uint256 userSalt) public;
```

### testGetRawPermissions


```solidity
function testGetRawPermissions(uint256 userSalt) public;
```

### testDenyPermissionBeingSetByAllower


```solidity
function testDenyPermissionBeingSetByAllower(uint256 userSalt) public;
```

### testUndeny


```solidity
function testUndeny(uint256 userSalt) public;
```

### testAllowerCantUndeny


```solidity
function testAllowerCantUndeny(uint256 userSalt) public;
```

### testRevertsOnIncorrectParameters


```solidity
function testRevertsOnIncorrectParameters(uint256 userSalt) public;
```

### testAllowFail


```solidity
function testAllowFail() public;
```

### testVersion


```solidity
function testVersion() external;
```

