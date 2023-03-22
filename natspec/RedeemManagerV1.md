# RedeemManagerV1

*Kiln*

> Redeem Manager (v1)

This contract handles the redeem requests of all users



## Methods

### claimRedeemRequests

```solidity
function claimRedeemRequests(uint32[] redeemRequestIds, uint32[] withdrawalEventIds) external nonpayable returns (uint8[] claimStatuses)
```

Claims the rewards of the provided redeem request ids



#### Parameters

| Name | Type | Description |
|---|---|---|
| redeemRequestIds | uint32[] | The list of redeem requests to claim |
| withdrawalEventIds | uint32[] | The list of withdrawal events to use for every redeem request claim |

#### Returns

| Name | Type | Description |
|---|---|---|
| claimStatuses | uint8[] | The list of claim statuses. 0 for fully claimed, 1 for partially claimed, 2 for skipped |

### claimRedeemRequests

```solidity
function claimRedeemRequests(uint32[] redeemRequestIds, uint32[] withdrawalEventIds, bool skipAlreadyClaimed) external nonpayable returns (uint8[] claimStatuses)
```

Claims the rewards of the provided redeem request ids



#### Parameters

| Name | Type | Description |
|---|---|---|
| redeemRequestIds | uint32[] | The list of redeem requests to claim |
| withdrawalEventIds | uint32[] | The list of withdrawal events to use for every redeem request claim |
| skipAlreadyClaimed | bool | True if the call should not revert on claiming of already claimed requests |

#### Returns

| Name | Type | Description |
|---|---|---|
| claimStatuses | uint8[] | The list of claim statuses. 0 for fully claimed, 1 for partially claimed, 2 for skipped |

### getBufferedExceedingEth

```solidity
function getBufferedExceedingEth() external view returns (uint256)
```

Retrieve the amount of eth available in the buffer




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of eth in the buffer |

### getRedeemRequestCount

```solidity
function getRedeemRequestCount() external view returns (uint256)
```

Retrieve the global count of redeem requests




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getRedeemRequestDetails

```solidity
function getRedeemRequestDetails(uint32 redeemRequestId) external view returns (struct RedeemQueue.RedeemRequest)
```

Retrieve the details of a specific redeem request



#### Parameters

| Name | Type | Description |
|---|---|---|
| redeemRequestId | uint32 | The id of the request |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | RedeemQueue.RedeemRequest | The redeem request details |

### getWithdrawalEventCount

```solidity
function getWithdrawalEventCount() external view returns (uint256)
```

Retrieve the global count of withdrawal events




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getWithdrawalEventDetails

```solidity
function getWithdrawalEventDetails(uint32 withdrawalEventId) external view returns (struct WithdrawalStack.WithdrawalEvent)
```

Retrieve the details of a specific withdrawal event



#### Parameters

| Name | Type | Description |
|---|---|---|
| withdrawalEventId | uint32 | The id of the withdrawal event |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | WithdrawalStack.WithdrawalEvent | The withdrawal event details |

### initializeRedeemManagerV1

```solidity
function initializeRedeemManagerV1(address river) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| river | address | The address of the River contract |

### pullExceedingEth

```solidity
function pullExceedingEth(uint256 max) external nonpayable
```

Pulls exceeding buffer eth



#### Parameters

| Name | Type | Description |
|---|---|---|
| max | uint256 | The maximum amount that should be pulled |

### reportWithdraw

```solidity
function reportWithdraw(uint256 lsETHWithdrawable) external payable
```

Reports a withdraw event from River



#### Parameters

| Name | Type | Description |
|---|---|---|
| lsETHWithdrawable | uint256 | The amount of LsETH that can be redeemed due to this new withdraw event |

### requestRedeem

```solidity
function requestRedeem(uint256 lsETHAmount, address recipient) external nonpayable returns (uint32 redeemRequestId)
```

Creates a redeem request



#### Parameters

| Name | Type | Description |
|---|---|---|
| lsETHAmount | uint256 | The amount of LsETH to redeem |
| recipient | address | The recipient owning the redeem request |

#### Returns

| Name | Type | Description |
|---|---|---|
| redeemRequestId | uint32 | The id of the redeem request |

### requestRedeem

```solidity
function requestRedeem(uint256 lsETHAmount) external nonpayable returns (uint32 redeemRequestId)
```

Creates a redeem request using msg.sender as recipient



#### Parameters

| Name | Type | Description |
|---|---|---|
| lsETHAmount | uint256 | The amount of LsETH to redeem |

#### Returns

| Name | Type | Description |
|---|---|---|
| redeemRequestId | uint32 | The id of the redeem request |

### resolveRedeemRequests

```solidity
function resolveRedeemRequests(uint32[] redeemRequestIds) external view returns (int64[] withdrawalEventIds)
```

Resolves the provided list of redeem request ids

*The result is an array of equal length with ids or error code-1 means that the request is not satisfied yet-2 means that the request is out of bounds-3 means that the request has already been claimedThis call was created to be called by an off-chain interface, the output could then be used to perform the claimRewards call in a regular transaction*

#### Parameters

| Name | Type | Description |
|---|---|---|
| redeemRequestIds | uint32[] | The list of redeem requests to resolve |

#### Returns

| Name | Type | Description |
|---|---|---|
| withdrawalEventIds | int64[] | The list of withdrawal events matching every redeem request (or error codes) |



## Events

### ClaimedRedeemRequest

```solidity
event ClaimedRedeemRequest(uint32 indexed redeemRequestId, address indexed recipient, uint256 ethAmount, uint256 lsEthAmount, uint256 remainingLsEthAmount)
```

Emitted when a redeem request claim has been processed and matched at least once and funds are sent to the recipient



#### Parameters

| Name | Type | Description |
|---|---|---|
| redeemRequestId `indexed` | uint32 | undefined |
| recipient `indexed` | address | undefined |
| ethAmount  | uint256 | undefined |
| lsEthAmount  | uint256 | undefined |
| remainingLsEthAmount  | uint256 | undefined |

### Initialize

```solidity
event Initialize(uint256 version, bytes cdata)
```

Emitted when the contract is properly initialized



#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint256 | undefined |
| cdata  | bytes | undefined |

### ReportedWithdrawal

```solidity
event ReportedWithdrawal(uint256 height, uint256 amount, uint256 ethAmount, uint32 id)
```

Emitted when a withdrawal event is created



#### Parameters

| Name | Type | Description |
|---|---|---|
| height  | uint256 | undefined |
| amount  | uint256 | undefined |
| ethAmount  | uint256 | undefined |
| id  | uint32 | undefined |

### RequestedRedeem

```solidity
event RequestedRedeem(address indexed owner, uint256 height, uint256 amount, uint32 id)
```

Emitted when a redeem request is created



#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| height  | uint256 | undefined |
| amount  | uint256 | undefined |
| id  | uint32 | undefined |

### SatisfiedRedeemRequest

```solidity
event SatisfiedRedeemRequest(uint32 indexed redeemRequestId, uint32 indexed withdrawalEventId, uint256 lsEthAmountSatisfied, uint256 ethAmountSatisfied, uint256 lsEthAmountRemaining, uint256 ethAmountExceeding)
```

Emitted when a redeem request has been satisfied and filled (even partially) from a withdrawal event



#### Parameters

| Name | Type | Description |
|---|---|---|
| redeemRequestId `indexed` | uint32 | undefined |
| withdrawalEventId `indexed` | uint32 | undefined |
| lsEthAmountSatisfied  | uint256 | undefined |
| ethAmountSatisfied  | uint256 | undefined |
| lsEthAmountRemaining  | uint256 | undefined |
| ethAmountExceeding  | uint256 | undefined |

### SentExceedingEth

```solidity
event SentExceedingEth(uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount  | uint256 | undefined |

### SetRiver

```solidity
event SetRiver(address river)
```

Emitted when the River address is set



#### Parameters

| Name | Type | Description |
|---|---|---|
| river  | address | undefined |



## Errors

### DoesNotMatch

```solidity
error DoesNotMatch(uint256 redeemRequestId, uint256 withdrawalEventId)
```

Thrown when the redeem request and withdrawal event are not matching during claim



#### Parameters

| Name | Type | Description |
|---|---|---|
| redeemRequestId | uint256 | The provided redeem request id |
| withdrawalEventId | uint256 | The provided associated withdrawal event id |

### IncompatibleArrayLengths

```solidity
error IncompatibleArrayLengths()
```

Thrown when the provided arrays don&#39;t have matching lengths




### InvalidInitialization

```solidity
error InvalidInitialization(uint256 version, uint256 expectedVersion)
```

An error occured during the initialization



#### Parameters

| Name | Type | Description |
|---|---|---|
| version | uint256 | The version that was attempting to be initialized |
| expectedVersion | uint256 | The version that was expected |

### InvalidZeroAddress

```solidity
error InvalidZeroAddress()
```

The address is zero




### InvalidZeroAmount

```solidity
error InvalidZeroAmount()
```

Thrown When a zero value is provided




### RedeemRequestAlreadyClaimed

```solidity
error RedeemRequestAlreadyClaimed(uint256 id)
```

Thrown when	the redeem request id is already claimed



#### Parameters

| Name | Type | Description |
|---|---|---|
| id | uint256 | The redeem request id |

### RedeemRequestOutOfBounds

```solidity
error RedeemRequestOutOfBounds(uint256 id)
```

Thrown when the provided redeem request id is out of bounds



#### Parameters

| Name | Type | Description |
|---|---|---|
| id | uint256 | The redeem request id |

### TransferError

```solidity
error TransferError()
```

Thrown when a transfer error occured with LsETH




### Unauthorized

```solidity
error Unauthorized(address caller)
```

The operator is unauthorized for the caller



#### Parameters

| Name | Type | Description |
|---|---|---|
| caller | address | Address performing the call |

### WithdrawalEventOutOfBounds

```solidity
error WithdrawalEventOutOfBounds(uint256 id)
```

Thrown when the withdrawal request id if out of bounds



#### Parameters

| Name | Type | Description |
|---|---|---|
| id | uint256 | The withdrawal event id |


