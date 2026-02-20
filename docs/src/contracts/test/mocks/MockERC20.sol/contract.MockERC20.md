# MockERC20
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/test/mocks/MockERC20.sol)

**Inherits:**
ERC20


## State Variables
### transferFromFail

```solidity
bool transferFromFail
```


## Functions
### constructor


```solidity
constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol);
```

### setTransferFromFail


```solidity
function setTransferFromFail(bool _fail) external;
```

### transferFrom


```solidity
function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool);
```

### mint


```solidity
function mint(address to, uint256 amount) external;
```

