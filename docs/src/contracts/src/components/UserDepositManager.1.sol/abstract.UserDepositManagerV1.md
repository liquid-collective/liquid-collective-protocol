# UserDepositManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/components/UserDepositManager.1.sol)

**Inherits:**
[IUserDepositManagerV1](/contracts/src/interfaces/components/IUserDepositManager.1.sol/interface.IUserDepositManagerV1.md)

**Title:**
User Deposit Manager (v1)

**Author:**
Alluvial Finance Inc.

This contract handles the inbound transfers cases or the explicit submissions


## Functions
### _onDeposit

Handler called whenever a user has sent funds to the contract

Must be overridden


```solidity
function _onDeposit(address _depositor, address _recipient, uint256 _amount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_depositor`|`address`|Address that made the deposit|
|`_recipient`|`address`|Address that receives the minted shares|
|`_amount`|`uint256`|Amount deposited|


### _setBalanceToDeposit


```solidity
function _setBalanceToDeposit(uint256 newBalanceToDeposit) internal virtual;
```

### deposit

Explicit deposit method to mint on msg.sender


```solidity
function deposit() external payable;
```

### depositAndTransfer

Explicit deposit method to mint on msg.sender and transfer to _recipient


```solidity
function depositAndTransfer(address _recipient) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|Address receiving the minted LsETH|


### receive

Implicit deposit method, when the user performs a regular transfer to the contract


```solidity
receive() external payable;
```

### fallback

Invalid call, when the user sends a transaction with a data payload but no method matched


```solidity
fallback() external payable;
```

### _deposit

Internal utility calling the deposit handler and emitting the deposit details


```solidity
function _deposit(address _recipient) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The account receiving the minted shares|


