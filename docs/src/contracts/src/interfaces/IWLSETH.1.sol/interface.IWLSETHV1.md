# IWLSETHV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/IWLSETH.1.sol)

**Title:**
Wrapped LsETH Interface (v1)

**Author:**
Alluvial Finance Inc.

This interface exposes methods to wrap the LsETH token into a rebase token.


## Functions
### initWLSETHV1

Initializes the wrapped token contract


```solidity
function initWLSETHV1(address _river) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_river`|`address`|Address of the River contract|


### name

Retrieves the token full name


```solidity
function name() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The name of the token|


### symbol

Retrieves the token symbol


```solidity
function symbol() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The symbol of the token|


### decimals

Retrieves the token decimal count


```solidity
function decimals() external pure returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The decimal count|


### totalSupply

Retrieves the token total supply


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total supply|


### balanceOf

Retrieves the token balance of the specified user


```solidity
function balanceOf(address _owner) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Owner to check the balance|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of the owner|


### sharesOf

Retrieves the raw shares count of the user


```solidity
function sharesOf(address _owner) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Owner to check the shares balance|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The shares of the owner|


### allowance

Retrieves the token allowance given from one address to another


```solidity
function allowance(address _owner, address _spender) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Owner that gave the allowance|
|`_spender`|`address`|Spender that received the allowance|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The allowance of the owner to the spender|


### transfer

Transfers tokens between the message sender and a recipient


```solidity
function transfer(address _to, uint256 _value) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|Recipient of the transfer|
|`_value`|`uint256`|Amount to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if success|


### transferFrom

Transfers tokens between two accounts

It is expected that _from has given at least _value allowance to msg.sender


```solidity
function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Sender account|
|`_to`|`address`|Recipient of the transfer|
|`_value`|`uint256`|Amount to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if success|


### approve

Approves another account to transfer tokens


```solidity
function approve(address _spender, uint256 _value) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_spender`|`address`|Spender that receives the allowance|
|`_value`|`uint256`|Amount to allow|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if success|


### increaseAllowance

Increase allowance to another account


```solidity
function increaseAllowance(address _spender, uint256 _additionalValue) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_spender`|`address`|Spender that receives the allowance|
|`_additionalValue`|`uint256`|Amount to add|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if success|


### decreaseAllowance

Decrease allowance to another account


```solidity
function decreaseAllowance(address _spender, uint256 _subtractableValue) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_spender`|`address`|Spender that receives the allowance|
|`_subtractableValue`|`uint256`|Amount to subtract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if success|


### mint

Mint tokens by providing LsETH tokens

The message sender locks LsETH tokens and received wrapped LsETH tokens in exchange

The message sender needs to approve the contract to mint the wrapped tokens

The minted wrapped LsETH is sent to the specified recipient


```solidity
function mint(address _recipient, uint256 _shares) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The account receiving the new minted wrapped LsETH|
|`_shares`|`uint256`|The amount of LsETH to wrap|


### burn

Burn tokens and retrieve underlying LsETH tokens

The message sender burns shares from its balance for the LsETH equivalent value

The message sender doesn't need to approve the contract to burn the shares

The freed LsETH is sent to the specified recipient


```solidity
function burn(address _recipient, uint256 _shares) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The account receiving the underlying LsETH tokens after shares are burned|
|`_shares`|`uint256`|Amount of LsETH to free by burning wrapped LsETH|


## Events
### Transfer
A transfer has been made


```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The transfer sender|
|`to`|`address`|The transfer recipient|
|`value`|`uint256`|The amount transfered|

### Approval
An approval has been made


```solidity
event Approval(address indexed owner, address indexed spender, uint256 value);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The token owner|
|`spender`|`address`|The account allowed by the owner|
|`value`|`uint256`|The amount allowed|

### Mint
Tokens have been minted


```solidity
event Mint(address indexed recipient, uint256 shares);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The account receiving the new tokens|
|`shares`|`uint256`|The amount of LsETH provided|

### Burn
Tokens have been burned


```solidity
event Burn(address indexed recipient, uint256 shares);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The account that receive the underlying LsETH|
|`shares`|`uint256`|The amount of LsETH that got sent back|

### SetRiver
The stored value of river has been changed


```solidity
event SetRiver(address indexed river);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`river`|`address`|The new address of river|

## Errors
### TokenTransferError
The token transfer failed during the minting or burning process


```solidity
error TokenTransferError();
```

### BalanceTooLow
Balance too low to perform operation


```solidity
error BalanceTooLow();
```

### AllowanceTooLow
Allowance too low to perform operation


```solidity
error AllowanceTooLow(address _from, address _operator, uint256 _allowance, uint256 _value);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Account where funds are sent from|
|`_operator`|`address`|Account attempting the transfer|
|`_allowance`|`uint256`|Current allowance|
|`_value`|`uint256`|Requested transfer value|

### Denied
The account is denied access


```solidity
error Denied(address _account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The denied account|

### NullTransfer
Invalid empty transfer


```solidity
error NullTransfer();
```

### UnauthorizedTransfer
Invalid transfer recipients


```solidity
error UnauthorizedTransfer(address _from, address _to);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Account sending the funds in the invalid transfer|
|`_to`|`address`|Account receiving the funds in the invalid transfer|

