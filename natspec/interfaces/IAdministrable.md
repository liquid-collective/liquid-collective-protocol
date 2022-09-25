# IAdministrable









## Methods

### acceptAdmin

```solidity
function acceptAdmin() external nonpayable
```






### getAdmin

```solidity
function getAdmin() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getPendingAdmin

```solidity
function getPendingAdmin() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### proposeAdmin

```solidity
function proposeAdmin(address _newAdmin) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _newAdmin | address | undefined |



## Events

### SetAdmin

```solidity
event SetAdmin(address indexed admin)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| admin `indexed` | address | undefined |

### SetPendingAdmin

```solidity
event SetPendingAdmin(address indexed pendingAdmin)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pendingAdmin `indexed` | address | undefined |



