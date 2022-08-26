# WLSETHV1

*Kiln*

> Wrapped lsETH v1

This contract wraps the lsETH token into a rebase token, more suitable for some DeFi use-cases         like stable swaps.



## Methods

### allowance

```solidity
function allowance(address _owner, address _spender) external view returns (uint256 remaining)
```

Retrieves the token allowance given from one address to another



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Owner that gave the allowance |
| _spender | address | Spender that received the allowance |

#### Returns

| Name | Type | Description |
|---|---|---|
| remaining | uint256 | undefined |

### approve

```solidity
function approve(address _spender, uint256 _value) external nonpayable returns (bool success)
```

Approves another account to transfer tokens



#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | Spender that receives the allowance |
| _value | uint256 | Amount to allow |

#### Returns

| Name | Type | Description |
|---|---|---|
| success | bool | undefined |

### balanceOf

```solidity
function balanceOf(address _owner) external view returns (uint256 balance)
```

Retrieves the token balance of the specified user



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Owner to check the balance |

#### Returns

| Name | Type | Description |
|---|---|---|
| balance | uint256 | undefined |

### burn

```solidity
function burn(address _recipient, uint256 _value) external nonpayable
```

Burn tokens and retrieve underlying River tokens

*Burned tokens are sent to recipient but are minted from the message sender balanceNo approval required from the message sender*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _recipient | address | Spender that receives the allowance |
| _value | uint256 | Amount of wrapped token to give to the burn |

### decimals

```solidity
function decimals() external pure returns (uint8)
```

Retrieves the token decimal count




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### initWLSETHV1

```solidity
function initWLSETHV1(address _river) external nonpayable
```

Initializes the wrapped token contract



#### Parameters

| Name | Type | Description |
|---|---|---|
| _river | address | Address of the River contract |

### mint

```solidity
function mint(address _recipient, uint256 _value) external nonpayable
```

Mint tokens by providing River tokens

*Minted tokens are sent to recipient but are minted from the message sender balanceIt is expected that the message sender approves _value amount of River token tothis contract before calling*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _recipient | address | Spender that receives the allowance |
| _value | uint256 | Amount of river token to give to the mint |

### name

```solidity
function name() external pure returns (string)
```

Retrieves the token full name




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### symbol

```solidity
function symbol() external pure returns (string)
```

Retrieves the token ticker




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```

Retrieves the token total supply




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfer

```solidity
function transfer(address _to, uint256 _value) external nonpayable returns (bool)
```

Transfers tokens between the message sender and a recipient



#### Parameters

| Name | Type | Description |
|---|---|---|
| _to | address | Recipient of the transfer |
| _value | uint256 | Amount to transfer |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferFrom

```solidity
function transferFrom(address _from, address _to, uint256 _value) external nonpayable returns (bool)
```

Transfers tokens between two accounts

*If _from is not the message sender, then it is expected that _from has given at leave _value allowance to msg.sender*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | Sender account |
| _to | address | Recipient of the transfer |
| _value | uint256 | Amount to transfer |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |



## Events

### Approval

```solidity
event Approval(address indexed _owner, address indexed _spender, uint256 _value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner `indexed` | address | undefined |
| _spender `indexed` | address | undefined |
| _value  | uint256 | undefined |

### Transfer

```solidity
event Transfer(address indexed _from, address indexed _to, uint256 _value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from `indexed` | address | undefined |
| _to `indexed` | address | undefined |
| _value  | uint256 | undefined |



## Errors

### AllowanceTooLow

```solidity
error AllowanceTooLow(address _from, address _operator, uint256 _allowance, uint256 _value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _operator | address | undefined |
| _allowance | uint256 | undefined |
| _value | uint256 | undefined |

### BalanceTooLow

```solidity
error BalanceTooLow()
```






### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | undefined |
| expectedVersion | uint256 | undefined |

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```






### NullTransfer

```solidity
error NullTransfer()
```






### TokenTransferError

```solidity
error TokenTransferError()
```






### UnauthorizedOperation

```solidity
error UnauthorizedOperation()
```







