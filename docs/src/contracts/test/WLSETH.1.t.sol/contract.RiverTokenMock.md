# RiverTokenMock
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/WLSETH.1.t.sol)


## State Variables
### balances

```solidity
mapping(address => uint256) internal balances
```


### approvals

```solidity
mapping(address => mapping(address => uint256)) internal approvals
```


### underlyingAssetTotal

```solidity
uint256 internal underlyingAssetTotal
```


### _totalSupply

```solidity
uint256 internal _totalSupply
```


### retVal

```solidity
bool internal retVal = true
```


### allowlistAddr

```solidity
address internal allowlistAddr
```


## Functions
### totalSupply


```solidity
function totalSupply() external view returns (uint256);
```

### totalUnderlyingSupply


```solidity
function totalUnderlyingSupply() external view returns (uint256);
```

### balanceOf


```solidity
function balanceOf(address _owner) external view returns (uint256 balance);
```

### balanceOfUnderlying


```solidity
function balanceOfUnderlying(address _owner) external view returns (uint256 balance);
```

### underlyingBalanceFromShares


```solidity
function underlyingBalanceFromShares(uint256 shares) external view returns (uint256);
```

### sharesFromUnderlyingBalance


```solidity
function sharesFromUnderlyingBalance(uint256 underlyingBalance) external view returns (uint256);
```

### transferFrom


```solidity
function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
```

### transfer


```solidity
function transfer(address _to, uint256 _value) external returns (bool);
```

### approve


```solidity
function approve(address _spender, uint256 _value) external;
```

### sudoSetUnderlyingTotal


```solidity
function sudoSetUnderlyingTotal(uint256 _total) external;
```

### sudoSetBalance


```solidity
function sudoSetBalance(address _who, uint256 _amount) external;
```

### sudoSetRetVal


```solidity
function sudoSetRetVal(bool _newVal) external;
```

### getAllowlist


```solidity
function getAllowlist() external view returns (address);
```

### sudoSetAllowlist


```solidity
function sudoSetAllowlist(address _allowlist) external;
```

