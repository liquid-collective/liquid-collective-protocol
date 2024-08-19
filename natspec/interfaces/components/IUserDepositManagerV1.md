# IUserDepositManagerV1

*Alluvial Finance Inc.*

> User Deposit Manager (v1)

This interface exposes methods to handle the inbound transfers cases or the explicit submissions



## Methods

### deposit

```solidity
function deposit() external payable
```

Explicit deposit method to mint on msg.sender




### depositAndTransfer

```solidity
function depositAndTransfer(address _recipient) external payable
```

Explicit deposit method to mint on msg.sender and transfer to _recipient



#### Parameters

| Name | Type | Description |
|---|---|---|
| _recipient | address | Address receiving the minted LsETH |



## Events

### UserDeposit

```solidity
event UserDeposit(address indexed depositor, address indexed recipient, uint256 amount)
```

User deposited ETH in the system



#### Parameters

| Name | Type | Description |
|---|---|---|
| depositor `indexed` | address | Address performing the deposit |
| recipient `indexed` | address | Address receiving the minted shares |
| amount  | uint256 | Amount in ETH deposited |



## Errors

### EmptyDeposit

```solidity
error EmptyDeposit()
```

And empty deposit attempt was made





