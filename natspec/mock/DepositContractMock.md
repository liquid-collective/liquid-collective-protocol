# DepositContractMock









## Methods

### deposit

```solidity
function deposit(bytes pubkey, bytes withdrawalCredentials, bytes signature, bytes32) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pubkey | bytes | undefined |
| withdrawalCredentials | bytes | undefined |
| signature | bytes | undefined |
| _3 | bytes32 | undefined |

### depositCount

```solidity
function depositCount() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### get_deposit_root

```solidity
function get_deposit_root() external view returns (bytes32)
```

Query the current deposit root hash.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | The deposit root hash. |

### receiver

```solidity
function receiver() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |



## Events

### DepositEvent

```solidity
event DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pubkey  | bytes | undefined |
| withdrawal_credentials  | bytes | undefined |
| amount  | bytes | undefined |
| signature  | bytes | undefined |
| index  | bytes | undefined |



