# WLSETHV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/WLSETH.1.sol)

**Inherits:**
[IWLSETHV1](/contracts/src/interfaces/IWLSETH.1.sol/interface.IWLSETHV1.md), [Initializable](/contracts/src/Initializable.sol/contract.Initializable.md), ReentrancyGuardUpgradeable

**Title:**
Wrapped LsETH (v1)

**Author:**
Alluvial Finance Inc.

This contract wraps the LsETH token into a rebase token, more suitable for some DeFi use-cases
like stable swaps.


## Functions
### isNotNull

Ensures that the value is not 0


```solidity
modifier isNotNull(uint256 _value) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_value`|`uint256`|Value that must be > 0|


### hasFunds

Ensures that the owner has enough funds


```solidity
modifier hasFunds(address _owner, uint256 _value) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Owner of the balance to verify|
|`_value`|`uint256`|Minimum required value|


### initWLSETHV1

Initializes the wrapped token contract


```solidity
function initWLSETHV1(address _river) external initializer;
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
function transfer(address _to, uint256 _value)
    external
    isNotNull(_value)
    hasFunds(msg.sender, _value)
    returns (bool);
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
function transferFrom(address _from, address _to, uint256 _value)
    external
    isNotNull(_value)
    hasFunds(_from, _value)
    returns (bool);
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


```solidity
function mint(address _recipient, uint256 _shares) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The account receiving the new minted wrapped LsETH|
|`_shares`|`uint256`|The amount of LsETH to wrap|


### burn

Burn tokens and retrieve underlying LsETH tokens

The message sender burns shares from its balance for the LsETH equivalent value


```solidity
function burn(address _recipient, uint256 _shares) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The account receiving the underlying LsETH tokens after shares are burned|
|`_shares`|`uint256`|Amount of LsETH to free by burning wrapped LsETH|


### _spendAllowance

Internal utility to spend the allowance of an account from the message sender


```solidity
function _spendAllowance(address _from, uint256 _value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Address owning the allowance|
|`_value`|`uint256`|Amount of allowance to spend|


### _approve

Internal utility to change the allowance of an owner to a spender


```solidity
function _approve(address _owner, address _spender, uint256 _value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The owner of the wrapped tokens|
|`_spender`|`address`|The allowed spender of the wrapped tokens|
|`_value`|`uint256`|The new allowance value|


### _balanceOf

Internal utility to retrieve the amount of token per owner


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
|`<none>`|`uint256`|The balance of the account|


### _transfer

Internal utility to perform a transfer with allowlist deny checks


```solidity
function _transfer(address _from, address _to, uint256 _value) internal returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Address sending the tokens|
|`_to`|`address`|Address receiving the tokens|
|`_value`|`uint256`|Amount to be sent|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if success|


