# ISharesManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/components/ISharesManager.1.sol)

**Inherits:**
IERC20

**Title:**
Shares Manager Interface (v1)

**Author:**
Alluvial Finance Inc.

This interface exposes methods to handle the shares of the depositor and the ERC20 interface


## Functions
### name

Retrieve the token name


```solidity
function name() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The token name|


### symbol

Retrieve the token symbol


```solidity
function symbol() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The token symbol|


### decimals

Retrieve the decimal count


```solidity
function decimals() external pure returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The decimal count|


### totalSupply

Retrieve the total token supply


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total supply in shares|


### totalUnderlyingSupply

Retrieve the total underlying asset supply


```solidity
function totalUnderlyingSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total underlying asset supply|


### balanceOf

Retrieve the balance of an account


```solidity
function balanceOf(address _owner) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Address to be checked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of the account in shares|


### balanceOfUnderlying

Retrieve the underlying asset balance of an account


```solidity
function balanceOfUnderlying(address _owner) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Address to be checked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The underlying balance of the account|


### underlyingBalanceFromShares

Retrieve the underlying asset balance from an amount of shares


```solidity
function underlyingBalanceFromShares(uint256 _shares) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_shares`|`uint256`|Amount of shares to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The underlying asset balance represented by the shares|


### sharesFromUnderlyingBalance

Retrieve the shares count from an underlying asset amount


```solidity
function sharesFromUnderlyingBalance(uint256 _underlyingAssetAmount) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_underlyingAssetAmount`|`uint256`|Amount of underlying asset to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of shares worth the underlying asset amopunt|


### allowance

Retrieve the allowance value for a spender


```solidity
function allowance(address _owner, address _spender) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Address that issued the allowance|
|`_spender`|`address`|Address that received the allowance|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The allowance in shares for a given spender|


### transfer

Performs a transfer from the message sender to the provided account


```solidity
function transfer(address _to, uint256 _value) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|Address receiving the tokens|
|`_value`|`uint256`|Amount of shares to be sent|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if success|


### transferFrom

Performs a transfer between two recipients


```solidity
function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Address sending the tokens|
|`_to`|`address`|Address receiving the tokens|
|`_value`|`uint256`|Amount of shares to be sent|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if success|


### approve

Approves an account for future spendings

An approved account can use transferFrom to transfer funds on behalf of the token owner


```solidity
function approve(address _spender, uint256 _value) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_spender`|`address`|Address that is allowed to spend the tokens|
|`_value`|`uint256`|The allowed amount in shares, will override previous value|

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
|`_additionalValue`|`uint256`|Amount of shares to add|

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
|`_subtractableValue`|`uint256`|Amount of shares to subtract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if success|


## Events
### SetTotalSupply
Emitted when the total supply is changed


```solidity
event SetTotalSupply(uint256 totalSupply);
```

## Errors
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
|`_value`|`uint256`|Requested transfer value in shares|

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

