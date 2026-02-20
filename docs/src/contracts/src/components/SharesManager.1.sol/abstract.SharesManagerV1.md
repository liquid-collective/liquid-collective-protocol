# SharesManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/components/SharesManager.1.sol)

**Inherits:**
[ISharesManagerV1](/contracts/src/interfaces/components/ISharesManager.1.sol/interface.ISharesManagerV1.md)

**Title:**
Shares Manager (v1)

**Author:**
Alluvial Finance Inc.

This contract handles the shares of the depositor and the ERC20 interface


## Functions
### _onTransfer

Internal hook triggered on the external transfer call

Must be overridden


```solidity
function _onTransfer(address _from, address _to) internal view virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Address of the sender|
|`_to`|`address`|Address of the recipient|


### _assetBalance

Internal method to override to provide the total underlying asset balance

Must be overridden


```solidity
function _assetBalance() internal view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total asset balance of the system|


### transferAllowed

Modifier used to ensure that the transfer is allowed by using the internal hook to perform internal checks


```solidity
modifier transferAllowed(address _from, address _to) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Address of the sender|
|`_to`|`address`|Address of the recipient|


### isNotZero

Modifier used to ensure the amount transferred is not 0


```solidity
modifier isNotZero(uint256 _value) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_value`|`uint256`|Amount to check|


### hasFunds

Modifier used to ensure that the sender has enough funds for the transfer


```solidity
modifier hasFunds(address _owner, uint256 _value) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Address of the sender|
|`_value`|`uint256`|Value that is required to be sent|


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
function balanceOfUnderlying(address _owner) public view returns (uint256);
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
function transfer(address _to, uint256 _value)
    external
    transferAllowed(msg.sender, _to)
    isNotZero(_value)
    hasFunds(msg.sender, _value)
    returns (bool);
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
function transferFrom(address _from, address _to, uint256 _value)
    external
    transferAllowed(_from, _to)
    isNotZero(_value)
    hasFunds(_from, _value)
    returns (bool);
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


### _spendAllowance

Internal utility to spend the allowance of an account from the message sender


```solidity
function _spendAllowance(address _from, uint256 _value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Address owning the allowance|
|`_value`|`uint256`|Amount of allowance in shares to spend|


### _approve

Internal utility to change the allowance of an owner to a spender


```solidity
function _approve(address _owner, address _spender, uint256 _value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The owner of the shares|
|`_spender`|`address`|The allowed spender of the shares|
|`_value`|`uint256`|The new allowance value|


### _totalSupply

Internal utility to retrieve the total supply of tokens


```solidity
function _totalSupply() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total supply|


### _transfer

Internal utility to perform an unchecked transfer


```solidity
function _transfer(address _from, address _to, uint256 _value) internal returns (bool);
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


### _balanceFromShares

Internal utility to retrieve the underlying asset balance for the given shares


```solidity
function _balanceFromShares(uint256 _shares) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_shares`|`uint256`|Amount of shares to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance from the given shares|


### _sharesFromBalance

Internal utility to retrieve the shares count for a given underlying asset amount


```solidity
function _sharesFromBalance(uint256 _balance) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_balance`|`uint256`|Amount of underlying asset balance to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The shares from the given balance|


### _mintShares

Internal utility to mint shares for the specified user

This method assumes that funds received are now part of the _assetBalance()


```solidity
function _mintShares(address _owner, uint256 _underlyingAssetValue) internal returns (uint256 sharesToMint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Account that should receive the new shares|
|`_underlyingAssetValue`|`uint256`|Value of underlying asset received, to convert into shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sharesToMint`|`uint256`|The amnount of minted shares|


### _balanceOf

Internal utility to retrieve the amount of shares per owner


```solidity
function _balanceOf(address _owner) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Account to be checked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of the account in shares|


### _mintRawShares

Internal utility to mint shares without any conversion, and emits a mint Transfer event


```solidity
function _mintRawShares(address _owner, uint256 _value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Account that should receive the new shares|
|`_value`|`uint256`|Amount of shares to mint|


### _burnRawShares

Internal utility to burn shares without any conversion, and emits a burn Transfer event


```solidity
function _burnRawShares(address _owner, uint256 _value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Account that should burn its shares|
|`_value`|`uint256`|Amount of shares to burn|


### _setTotalSupply

Internal utility to set the total supply and emit an event


```solidity
function _setTotalSupply(uint256 newTotalSupply) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTotalSupply`|`uint256`|The new total supply value|


