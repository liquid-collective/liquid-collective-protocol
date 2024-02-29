# IRedeemManagerV1

**Kiln**

> Redeem Manager Interface (v1)

This contract handles the redeem requests of all users



## Methods

### claimRedeemRequests

```solidity
function claimRedeemRequests(uint32[] _redeemRequestIds, uint32[] _withdrawalEventIds, bool _skipAlreadyClaimed, uint16 _depth) external nonpayable returns (uint8[] claimStatuses)
```

Claims the rewards of the provided redeem request ids



#### Parameters

| Name | Type | Description |
|---|---|---|
| _redeemRequestIds | uint32[] | The list of redeem requests to claim |
| _withdrawalEventIds | uint32[] | The list of withdrawal events to use for every redeem request claim |
| _skipAlreadyClaimed | bool | True if the call should not revert on claiming of already claimed requests |
| _depth | uint16 | The maximum recursive depth for the resolution of the redeem requests |

#### Returns

| Name | Type | Description |
|---|---|---|
| claimStatuses | uint8[] | The list of claim statuses. 0 for fully claimed, 1 for partially claimed, 2 for skipped |

### claimRedeemRequests

```solidity
function claimRedeemRequests(uint32[] _redeemRequestIds, uint32[] _withdrawalEventIds) external nonpayable returns (uint8[] claimStatuses)
```

Claims the rewards of the provided redeem request ids



#### Parameters

| Name | Type | Description |
|---|---|---|
| _redeemRequestIds | uint32[] | The list of redeem requests to claim |
| _withdrawalEventIds | uint32[] | The list of withdrawal events to use for every redeem request claim |

#### Returns

| Name | Type | Description |
|---|---|---|
| claimStatuses | uint8[] | The list of claim statuses. 0 for fully claimed, 1 for partially claimed, 2 for skipped |

### getBufferedExceedingEth

```solidity
function getBufferedExceedingEth() external view returns (uint256)
```

Retrieve the amount of redeemed LsETH pending to be supplied with withdrawn ETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of eth in the buffer |

### getRedeemDemand

```solidity
function getRedeemDemand() external view returns (uint256)
```

Retrieve the amount of LsETH waiting to be exited




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The amount of LsETH waiting to be exited |

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
function getRedeemRequestDetails(uint32 _redeemRequestId) external view returns (struct RedeemQueue.RedeemRequest)
```

Retrieve the details of a specific redeem request



#### Parameters

| Name | Type | Description |
|---|---|---|
| _redeemRequestId | uint32 | The id of the request |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | RedeemQueue.RedeemRequest | The redeem request details |

### getRiver

```solidity
function getRiver() external view returns (address)
```

Retrieve River address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | The address of River |

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
function getWithdrawalEventDetails(uint32 _withdrawalEventId) external view returns (struct WithdrawalStack.WithdrawalEvent)
```

Retrieve the details of a specific withdrawal event



#### Parameters

| Name | Type | Description |
|---|---|---|
| _withdrawalEventId | uint32 | The id of the withdrawal event |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | WithdrawalStack.WithdrawalEvent | The withdrawal event details |

### initializeRedeemManagerV1

```solidity
function initializeRedeemManagerV1(address _river) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _river | address | The address of the River contract |

### pullExceedingEth

```solidity
function pullExceedingEth(uint256 _max) external nonpayable
```

Pulls exceeding buffer eth



#### Parameters

| Name | Type | Description |
|---|---|---|
| _max | uint256 | The maximum amount that should be pulled |

### reportWithdraw

```solidity
function reportWithdraw(uint256 _lsETHWithdrawable) external payable
```

Reports a withdraw event from River



#### Parameters

| Name | Type | Description |
|---|---|---|
| _lsETHWithdrawable | uint256 | The amount of LsETH that can be redeemed due to this new withdraw event |

### requestRedeem

```solidity
function requestRedeem(uint256 _lsETHAmount, address _recipient) external nonpayable returns (uint32 redeemRequestId)
```

Creates a redeem request



#### Parameters

| Name | Type | Description |
|---|---|---|
| _lsETHAmount | uint256 | The amount of LsETH to redeem |
| _recipient | address | The recipient owning the redeem request |

#### Returns

| Name | Type | Description |
|---|---|---|
| redeemRequestId | uint32 | The id of the redeem request |

### requestRedeem

```solidity
function requestRedeem(uint256 _lsETHAmount) external nonpayable returns (uint32 redeemRequestId)
```

Creates a redeem request using msg.sender as recipient



#### Parameters

| Name | Type | Description |
|---|---|---|
| _lsETHAmount | uint256 | The amount of LsETH to redeem |

#### Returns

| Name | Type | Description |
|---|---|---|
| redeemRequestId | uint32 | The id of the redeem request |

### resolveRedeemRequests

```solidity
function resolveRedeemRequests(uint32[] _redeemRequestIds) external view returns (int64[] withdrawalEventIds)
```

Resolves the provided list of redeem request ids

*The result is an array of equal length with ids or error code-1 means that the request is not satisfied yet-2 means that the request is out of bounds-3 means that the request has already been claimedThis call was created to be called by an off-chain interface, the output could then be used to perform the claimRewards call in a regular transaction*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _redeemRequestIds | uint32[] | The list of redeem requests to resolve |

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
| redeemRequestId `indexed` | uint32 | The id of the redeem request |
| recipient `indexed` | address | The address receiving the redeem request funds |
| ethAmount  | uint256 | The amount of eth retrieved |
| lsEthAmount  | uint256 | The total amount of LsETH used to redeem the eth |
| remainingLsEthAmount  | uint256 | The amount of LsETH remaining |

### ReportedWithdrawal

```solidity
event ReportedWithdrawal(uint256 height, uint256 amount, uint256 ethAmount, uint32 id)
```

Emitted when a withdrawal event is created



#### Parameters

| Name | Type | Description |
|---|---|---|
| height  | uint256 | The height of the withdrawal event in LsETH |
| amount  | uint256 | The amount of the withdrawal event in LsETH |
| ethAmount  | uint256 | The amount of eth to distrubute to claimers |
| id  | uint32 | The id of the withdrawal event |

### RequestedRedeem

```solidity
event RequestedRedeem(address indexed owner, uint256 height, uint256 amount, uint256 maxRedeemableEth, uint32 id)
```

Emitted when a redeem request is created



#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | The owner of the redeem request |
| height  | uint256 | The height of the redeem request in LsETH |
| amount  | uint256 | The amount of the redeem request in LsETH |
| maxRedeemableEth  | uint256 | The maximum amount of eth that can be redeemed from this request |
| id  | uint32 | The id of the new redeem request |

### SatisfiedRedeemRequest

```solidity
event SatisfiedRedeemRequest(uint32 indexed redeemRequestId, uint32 indexed withdrawalEventId, uint256 lsEthAmountSatisfied, uint256 ethAmountSatisfied, uint256 lsEthAmountRemaining, uint256 ethAmountExceeding)
```

Emitted when a redeem request has been satisfied and filled (even partially) from a withdrawal event



#### Parameters

| Name | Type | Description |
|---|---|---|
| redeemRequestId `indexed` | uint32 | The id of the redeem request |
| withdrawalEventId `indexed` | uint32 | The id of the withdrawal event used to fill the request |
| lsEthAmountSatisfied  | uint256 | The amount of LsETH filled |
| ethAmountSatisfied  | uint256 | The amount of ETH filled |
| lsEthAmountRemaining  | uint256 | The amount of LsETH remaining |
| ethAmountExceeding  | uint256 | The amount of eth added to the exceeding buffer |

### SetRedeemDemand

```solidity
event SetRedeemDemand(uint256 oldRedeemDemand, uint256 newRedeemDemand)
```

Emitted when the redeem demand is set



#### Parameters

| Name | Type | Description |
|---|---|---|
| oldRedeemDemand  | uint256 | The old redeem demand |
| newRedeemDemand  | uint256 | The new redeem demand |

### SetRiver

```solidity
event SetRiver(address river)
```

Emitted when the River address is set



#### Parameters

| Name | Type | Description |
|---|---|---|
| river  | address | The new river address |



## Errors

### ClaimRedeemFailed

```solidity
error ClaimRedeemFailed(address recipient, bytes rdata)
```

Thrown when the payment after a claim failed



#### Parameters

| Name | Type | Description |
|---|---|---|
| recipient | address | The recipient of the payment |
| rdata | bytes | The revert data |

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




### WithdrawalEventOutOfBounds

```solidity
error WithdrawalEventOutOfBounds(uint256 id)
```

Thrown when the withdrawal request id if out of bounds



#### Parameters

| Name | Type | Description |
|---|---|---|
| id | uint256 | The withdrawal event id |

### WithdrawalExceedsRedeemDemand

```solidity
error WithdrawalExceedsRedeemDemand(uint256 withdrawalAmount, uint256 redeemDemand)
```

Thrown when the provided withdrawal event exceeds the redeem demand



#### Parameters

| Name | Type | Description |
|---|---|---|
| withdrawalAmount | uint256 | The amount of the withdrawal event |
| redeemDemand | uint256 | The current redeem demand |


