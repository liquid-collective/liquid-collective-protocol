# SharesManagerV1

*Alluvial Finance Inc.*

> Shares Manager (v1)

This contract handles the shares of the depositor and the ERC20 interface



## Methods

### allowance

```solidity
function allowance(address _owner, address _spender) external view returns (uint256)
```

Retrieve the allowance value for a spender



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Address that issued the allowance |
| _spender | address | Address that received the allowance |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The allowance in shares for a given spender |

### approve

```solidity
function approve(address _spender, uint256 _value) external nonpayable returns (bool)
```

Approves an account for future spendings

*An approved account can use transferFrom to transfer funds on behalf of the token owner*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | Address that is allowed to spend the tokens |
| _value | uint256 | The allowed amount in shares, will override previous value |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

### balanceOf

```solidity
function balanceOf(address _owner) external view returns (uint256)
```

Retrieve the balance of an account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Address to be checked |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The balance of the account in shares |

### balanceOfUnderlying

```solidity
function balanceOfUnderlying(address _owner) external view returns (uint256)
```

Retrieve the underlying asset balance of an account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Address to be checked |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The underlying balance of the account |

### decimals

```solidity
function decimals() external pure returns (uint8)
```

Retrieve the decimal count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | The decimal count |

### decreaseAllowance

```solidity
function decreaseAllowance(address _spender, uint256 _subtractableValue) external nonpayable returns (bool)
```

Decrease allowance to another account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | Spender that receives the allowance |
| _subtractableValue | uint256 | Amount of shares to subtract |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

### increaseAllowance

```solidity
function increaseAllowance(address _spender, uint256 _additionalValue) external nonpayable returns (bool)
```

Increase allowance to another account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | Spender that receives the allowance |
| _additionalValue | uint256 | Amount of shares to add |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

### name

```solidity
function name() external pure returns (string)
```

Retrieve the token name




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | The token name |

### sharesFromUnderlyingBalance

```solidity
function sharesFromUnderlyingBalance(uint256 _underlyingAssetAmount) external view returns (uint256)
```

Retrieve the shares count from an underlying asset amount



#### Parameters

| Name | Type | Description |
|---|---|---|
| _underlyingAssetAmount | uint256 | Amount of underlying asset to convert |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of shares worth the underlying asset amopunt |

### symbol

```solidity
function symbol() external pure returns (string)
```

Retrieve the token symbol




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | The token symbol |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```

Retrieve the total token supply




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The total supply in shares |

### totalUnderlyingSupply

```solidity
function totalUnderlyingSupply() external view returns (uint256)
```

Retrieve the total underlying asset supply




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The total underlying asset supply |

### transfer

```solidity
function transfer(address _to, uint256 _value) external nonpayable returns (bool)
```

Performs a transfer from the message sender to the provided account



#### Parameters

| Name | Type | Description |
|---|---|---|
| _to | address | Address receiving the tokens |
| _value | uint256 | Amount of shares to be sent |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

### transferFrom

```solidity
function transferFrom(address _from, address _to, uint256 _value) external nonpayable returns (bool)
```

Performs a transfer between two recipients



#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | Address sending the tokens |
| _to | address | Address receiving the tokens |
| _value | uint256 | Amount of shares to be sent |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

### underlyingBalanceFromShares

```solidity
function underlyingBalanceFromShares(uint256 _shares) external view returns (uint256)
```

Retrieve the underlying asset balance from an amount of shares



#### Parameters

| Name | Type | Description |
|---|---|---|
| _shares | uint256 | Amount of shares to convert |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The underlying asset balance represented by the shares |



## Events

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```



*Emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}. `value` is the new allowance.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| value  | uint256 | undefined |

### SetTotalSupply

```solidity
event SetTotalSupply(uint256 totalSupply)
```

Emitted when the total supply is changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| totalSupply  | uint256 | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```



*Emitted when `value` tokens are moved from one account (`from`) to another (`to`). Note that `value` may be zero.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| value  | uint256 | undefined |



## Errors

### AllowanceTooLow

```solidity
error AllowanceTooLow(address _from, address _operator, uint256 _allowance, uint256 _value)
```

Allowance too low to perform operation



#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | Account where funds are sent from |
| _operator | address | Account attempting the transfer |
| _allowance | uint256 | Current allowance |
| _value | uint256 | Requested transfer value in shares |

### BalanceTooLow

```solidity
error BalanceTooLow()
```

Balance too low to perform operation




### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero




### NullTransfer

```solidity
error NullTransfer()
```

Invalid empty transfer




### UnauthorizedTransfer

```solidity
error UnauthorizedTransfer(address _from, address _to)
```

Invalid transfer recipients



#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | Account sending the funds in the invalid transfer |
| _to | address | Account receiving the funds in the invalid transfer |


