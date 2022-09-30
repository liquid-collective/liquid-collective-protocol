# UserDepositManagerV1

*Kiln*

> User Deposit Manager (v1)

This contract handles the inbound transfers cases or the explicit submissions



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
| depositor `indexed` | address | undefined |
| recipient `indexed` | address | undefined |
| amount  | uint256 | undefined |



## Errors

### EmptyDeposit

```solidity
error EmptyDeposit()
```

And empty deposit attempt was made




### InvalidCall

```solidity
error InvalidCall()
```

The call was invalid




### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero





