# IWithdrawV1

*Kiln*

> Withdraw Interface (V1)

This contract is in charge of holding the exit and skimming funds and allow river to pull these funds



## Methods

### getCredentials

```solidity
function getCredentials() external view returns (bytes32)
```

Retrieve the withdrawal credentials to use




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | The withdrawal credentials |

### getRiver

```solidity
function getRiver() external view returns (address)
```

Retrieve the linked River address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The River address |

### initializeWithdrawV1

```solidity
function initializeWithdrawV1(address river) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| river | address | The address of the River contract |

### pullEth

```solidity
function pullEth(uint256 amount) external nonpayable
```

Callable by River, sends the specified amount of ETH to River



#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | The amount to pull |



## Events

### SetRiver

```solidity
event SetRiver(address river)
```

Emitted when the linked River address is changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| river  | address | The new River address |



