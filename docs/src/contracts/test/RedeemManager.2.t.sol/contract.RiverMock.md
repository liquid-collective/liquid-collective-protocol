# RiverMock
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/RedeemManager.2.t.sol)

**Inherits:**
[MockERC20](/contracts/test/mocks/MockERC20.sol/contract.MockERC20.md)


## State Variables
### balances

```solidity
mapping(address => uint256) internal balances
```


### approvals

```solidity
mapping(address => mapping(address => uint256)) internal approvals
```


### allowlist

```solidity
address internal allowlist
```


### rate

```solidity
uint256 internal rate = 1e18
```


### _totalSupply

```solidity
uint256 internal _totalSupply
```


## Functions
### constructor


```solidity
constructor(address _allowlist) MockERC20("Mock River", "MRIV", 18);
```

### approve


```solidity
function approve(address to, uint256 amount) public virtual override returns (bool);
```

### transferFrom


```solidity
function transferFrom(address from, address to, uint256 amount) public override returns (bool);
```

### balanceOf


```solidity
function balanceOf(address account) public view virtual override returns (uint256);
```

### sudoDeal

Sets the balance of the given account and updates totalSupply


```solidity
function sudoDeal(address account, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to set the balance of|
|`amount`|`uint256`|Amount to set as balance|


### sudoSetRate


```solidity
function sudoSetRate(uint256 newRate) external;
```

### getAllowlist


```solidity
function getAllowlist() external view returns (address);
```

### sudoReportWithdraw


```solidity
function sudoReportWithdraw(address redeemManager, uint256 lsETHAmount) external payable;
```

### totalSupply


```solidity
function totalSupply() public view virtual override returns (uint256);
```

### totalUnderlyingSupply


```solidity
function totalUnderlyingSupply() external view returns (uint256);
```

### underlyingBalanceFromShares


```solidity
function underlyingBalanceFromShares(uint256 shares) external view returns (uint256);
```

### pullExceedingEth


```solidity
function pullExceedingEth(address redeemManager, uint256 amount) external;
```

### fallback


```solidity
fallback() external payable;
```

### receive


```solidity
receive() external payable;
```

## Errors
### ApprovedAmountTooLow

```solidity
error ApprovedAmountTooLow();
```

