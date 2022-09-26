# IUserDepositManagerV1









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
| _recipient | address | Address receiving the minted lsETH |

### getPendingEth

```solidity
function getPendingEth() external view returns (uint256)
```

Returns the amount of pending ETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of pending eth |



## Events

### UserDeposit

```solidity
event UserDeposit(address indexed depositor, address indexed recipient, uint256 amount)
```

User deposited eth in the system



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





