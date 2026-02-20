# IUserDepositManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/components/IUserDepositManager.1.sol)

**Title:**
User Deposit Manager (v1)

**Author:**
Alluvial Finance Inc.

This interface exposes methods to handle the inbound transfers cases or the explicit submissions


## Functions
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

## Events
### UserDeposit
User deposited ETH in the system


```solidity
event UserDeposit(address indexed depositor, address indexed recipient, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositor`|`address`|Address performing the deposit|
|`recipient`|`address`|Address receiving the minted shares|
|`amount`|`uint256`|Amount in ETH deposited|

## Errors
### EmptyDeposit
And empty deposit attempt was made


```solidity
error EmptyDeposit();
```

