# ConsensusLayerDepositManagerV1ErrorTests
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/components/ConsensusLayerDepositManager.1.t.sol)

**Inherits:**
[OperatorAllocationTestBase](/contracts/test/OperatorAllocationTestBase.sol/abstract.OperatorAllocationTestBase.md)


## State Variables
### withdrawalCredentials

```solidity
bytes32 internal withdrawalCredentials = bytes32(uint256(1))
```


### depositManager

```solidity
ConsensusLayerDepositManagerV1 internal depositManager
```


### depositContract

```solidity
IDepositContract internal depositContract
```


## Functions
### setUp


```solidity
function setUp() public;
```

### testInconsistentPublicKey


```solidity
function testInconsistentPublicKey() public;
```

### testInconsistentSignature


```solidity
function testInconsistentSignature() public;
```

### testUnavailableKeys


```solidity
function testUnavailableKeys() public;
```

### testInvalidPublicKeyCount


```solidity
function testInvalidPublicKeyCount() public;
```

### testFaultyRegistryReturnsFewerKeys


```solidity
function testFaultyRegistryReturnsFewerKeys() public;
```

### testFaultyRegistryReturnsMoreKeysThanRequested


```solidity
function testFaultyRegistryReturnsMoreKeysThanRequested() public;
```

### testAllocationExceedsCommittedBalance


```solidity
function testAllocationExceedsCommittedBalance() public;
```

### testAllocationExceedsCommittedBalanceByOne

Fund with exactly 2 deposits (64 ETH). Request allocation of 3 validators.
Verify OperatorAllocationsExceedCommittedBalance().


```solidity
function testAllocationExceedsCommittedBalanceByOne() public;
```

### testAllocationExceedsCommittedBalanceMultiOperator

Fund with 3 deposits (96 ETH). Request [op0: 2, op1: 2] = 4 total.
Verify OperatorAllocationsExceedCommittedBalance().


```solidity
function testAllocationExceedsCommittedBalanceMultiOperator() public;
```

### testAllocationExactlyMatchesCommittedBalance

Fund with 3 deposits. Request exactly 3 validators. Verify it succeeds (no revert).


```solidity
function testAllocationExactlyMatchesCommittedBalance() public;
```

