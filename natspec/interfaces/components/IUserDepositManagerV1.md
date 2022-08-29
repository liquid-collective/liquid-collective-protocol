# IUserDepositManagerV1









## Methods

### deposit

```solidity
function deposit() external payable
```






### depositAndTransfer

```solidity
function depositAndTransfer(address _recipient) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _recipient | address | undefined |

### getPendingEth

```solidity
function getPendingEth() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |



## Events

### UserDeposit

```solidity
event UserDeposit(address indexed depositor, address indexed recipient, uint256 amount)
```





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






### EmptyDonation

```solidity
error EmptyDonation()
```







