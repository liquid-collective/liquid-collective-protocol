# WLSETHV1

*Kiln*

> Wrapped lsETH v1

This contract wraps the lsETH token into a rebase token, more suitable for some DeFi use-cases         like stable swaps.



## Methods

### allowance

```solidity
function allowance(address _owner, address _spender) external view returns (uint256)
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
| _0 | uint256 | The allowance of the owner to the spender |

### approve

```solidity
function approve(address _spender, uint256 _value) external nonpayable returns (bool)
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
| _0 | bool | True if success |

### balanceOf

```solidity
function balanceOf(address _owner) external view returns (uint256)
```

Retrieves the token balance of the specified user



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Owner to check the balance |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The balance of the owner |

### burn

```solidity
function burn(address _recipient, uint256 _shares) external nonpayable
```

Burn tokens and retrieve underlying LsETH tokens

*Burned tokens are sent to recipient but are minted from the message sender balanceNo approval required from the message sender*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _recipient | address | Spender that receives the allowance |
| _shares | uint256 | Amount of shares to burn |

### decimals

```solidity
function decimals() external pure returns (uint8)
```

Retrieves the token decimal count




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
| _subtractableValue | uint256 | Amount to subtract |

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
| _additionalValue | uint256 | Amount to add |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |

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

Mint tokens by providing LsETH tokens

*Minted tokens are sent to recipient but are minted from the message sender balanceIt is expected that the message sender approves _value amount of LsETH token tothis contract before calling*

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
| _0 | string | The name of the token |

### sharesOf

```solidity
function sharesOf(address _owner) external view returns (uint256)
```

Retrieves the raw shares count of the user



#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Owner to check the shares balance |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The shares of the owner |

### symbol

```solidity
function symbol() external pure returns (string)
```

Retrieves the token symbol




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | The symbol of the token |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```

Retrieves the token total supply




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The total supply |

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
| _0 | bool | True if success |

### transferFrom

```solidity
function transferFrom(address _from, address _to, uint256 _value) external nonpayable returns (bool)
```

Transfers tokens between two accounts

*It is expected that _from has given at least _value allowance to msg.sender*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | Sender account |
| _to | address | Recipient of the transfer |
| _value | uint256 | Amount to transfer |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | True if success |



## Events

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```

An approval has been made



#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| value  | uint256 | undefined |

### Burn

```solidity
event Burn(address indexed recipient, uint256 shares)
```

Tokens have been burned



#### Parameters

| Name | Type | Description |
|---|---|---|
| recipient `indexed` | address | undefined |
| shares  | uint256 | undefined |

### Initialize

```solidity
event Initialize(uint256 version, bytes cdata)
```

Emitted when the contract is properly initialized



#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint256 | undefined |
| cdata  | bytes | undefined |

### Mint

```solidity
event Mint(address indexed recipient, uint256 value)
```

Tokens have been minted



#### Parameters

| Name | Type | Description |
|---|---|---|
| recipient `indexed` | address | undefined |
| value  | uint256 | undefined |

### SetRiver

```solidity
event SetRiver(address indexed river)
```

The stored value of river has been changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| river `indexed` | address | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```

A transfer has been made



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
| _value | uint256 | Requested transfer value |

### BalanceTooLow

```solidity
error BalanceTooLow()
```

Balance too low to perform operation




### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```

An error occured during the initialization



#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | The version that was attempting the be initialized |
| expectedVersion | uint256 | The version that was expected |

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




### TokenTransferError

```solidity
error TokenTransferError()
```

The token transfer failed during the minting or burning process




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


