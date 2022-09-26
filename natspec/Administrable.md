# Administrable

*Kiln*

> Administrable

This contract handles the ownership of the contracts



## Methods

### acceptAdmin

```solidity
function acceptAdmin() external nonpayable
```

Accept the transfer of ownership

*Only callable by the pending admin. Resets the pending admin if succesful.*


### getAdmin

```solidity
function getAdmin() external view returns (address)
```

Retrieves the current admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The admin address |

### getPendingAdmin

```solidity
function getPendingAdmin() external view returns (address)
```

Retrieve the current pending admin address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The pending admin address |

### proposeAdmin

```solidity
function proposeAdmin(address _newAdmin) external nonpayable
```

Proposes a new address as admin

*This security prevents setting and invalid address as an admin. The pendingadmin has to claim its ownership of the contract, and proves that the newaddress is able to perform regular transactions.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | New admin address |



## Events

### SetAdmin

```solidity
event SetAdmin(address indexed admin)
```

The admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| admin `indexed` | address | undefined |

### SetPendingAdmin

```solidity
event SetPendingAdmin(address indexed pendingAdmin)
```

The pending admin address changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| pendingAdmin `indexed` | address | undefined |



## Errors

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```






### Unauthorized

```solidity
error Unauthorized(address caller)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | undefined |


