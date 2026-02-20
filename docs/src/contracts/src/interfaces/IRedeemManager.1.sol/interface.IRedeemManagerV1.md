# IRedeemManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/IRedeemManager.1.sol)

**Title:**
Redeem Manager Interface (v1)

**Author:**
Alluvial Finance Inc.

This contract handles the redeem requests of all users


## Functions
### initializeRedeemManagerV1


```solidity
function initializeRedeemManagerV1(address _river) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_river`|`address`|The address of the River contract|


### initializeRedeemManagerV1_2


```solidity
function initializeRedeemManagerV1_2() external;
```

### getRiver

Retrieve River address


```solidity
function getRiver() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of River|


### getRedeemRequestCount

Retrieve the global count of redeem requests


```solidity
function getRedeemRequestCount() external view returns (uint256);
```

### getRedeemRequestDetails

Retrieve the details of a specific redeem request


```solidity
function getRedeemRequestDetails(uint32 _redeemRequestId) external view returns (RedeemQueueV2.RedeemRequest memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequestId`|`uint32`|The id of the request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`RedeemQueueV2.RedeemRequest`|The redeem request details|


### getWithdrawalEventCount

Retrieve the global count of withdrawal events


```solidity
function getWithdrawalEventCount() external view returns (uint256);
```

### getWithdrawalEventDetails

Retrieve the details of a specific withdrawal event


```solidity
function getWithdrawalEventDetails(uint32 _withdrawalEventId)
    external
    view
    returns (WithdrawalStack.WithdrawalEvent memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_withdrawalEventId`|`uint32`|The id of the withdrawal event|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`WithdrawalStack.WithdrawalEvent`|The withdrawal event details|


### getBufferedExceedingEth

Retrieve the amount of redeemed LsETH pending to be supplied with withdrawn ETH


```solidity
function getBufferedExceedingEth() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of eth in the buffer|


### getRedeemDemand

Retrieve the amount of LsETH waiting to be exited


```solidity
function getRedeemDemand() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of LsETH waiting to be exited|


### resolveRedeemRequests

Resolves the provided list of redeem request ids

The result is an array of equal length with ids or error code

-1 means that the request is not satisfied yet

-2 means that the request is out of bounds

-3 means that the request has already been claimed

This call was created to be called by an off-chain interface, the output could then be used to perform the claimRewards call in a regular transaction


```solidity
function resolveRedeemRequests(uint32[] calldata _redeemRequestIds)
    external
    view
    returns (int64[] memory withdrawalEventIds);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequestIds`|`uint32[]`|The list of redeem requests to resolve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`withdrawalEventIds`|`int64[]`|The list of withdrawal events matching every redeem request (or error codes)|


### requestRedeem

Creates a redeem request


```solidity
function requestRedeem(uint256 _lsETHAmount, address _recipient) external returns (uint32 redeemRequestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lsETHAmount`|`uint256`|The amount of LsETH to redeem|
|`_recipient`|`address`|The recipient owning the redeem request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`redeemRequestId`|`uint32`|The id of the redeem request|


### requestRedeem

Creates a redeem request using msg.sender as recipient


```solidity
function requestRedeem(uint256 _lsETHAmount) external returns (uint32 redeemRequestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lsETHAmount`|`uint256`|The amount of LsETH to redeem|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`redeemRequestId`|`uint32`|The id of the redeem request|


### claimRedeemRequests

Claims the rewards of the provided redeem request ids


```solidity
function claimRedeemRequests(
    uint32[] calldata _redeemRequestIds,
    uint32[] calldata _withdrawalEventIds,
    bool _skipAlreadyClaimed,
    uint16 _depth
) external returns (uint8[] memory claimStatuses);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequestIds`|`uint32[]`|The list of redeem requests to claim|
|`_withdrawalEventIds`|`uint32[]`|The list of withdrawal events to use for every redeem request claim|
|`_skipAlreadyClaimed`|`bool`|True if the call should not revert on claiming of already claimed requests|
|`_depth`|`uint16`|The maximum recursive depth for the resolution of the redeem requests|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`claimStatuses`|`uint8[]`|The list of claim statuses. 0 for fully claimed, 1 for partially claimed, 2 for skipped|


### claimRedeemRequests

Claims the rewards of the provided redeem request ids


```solidity
function claimRedeemRequests(uint32[] calldata _redeemRequestIds, uint32[] calldata _withdrawalEventIds)
    external
    returns (uint8[] memory claimStatuses);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequestIds`|`uint32[]`|The list of redeem requests to claim|
|`_withdrawalEventIds`|`uint32[]`|The list of withdrawal events to use for every redeem request claim|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`claimStatuses`|`uint8[]`|The list of claim statuses. 0 for fully claimed, 1 for partially claimed, 2 for skipped|


### reportWithdraw

Reports a withdraw event from River


```solidity
function reportWithdraw(uint256 _lsETHWithdrawable) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lsETHWithdrawable`|`uint256`|The amount of LsETH that can be redeemed due to this new withdraw event|


### pullExceedingEth

Pulls exceeding buffer eth


```solidity
function pullExceedingEth(uint256 _max) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_max`|`uint256`|The maximum amount that should be pulled|


## Events
### RequestedRedeem
Emitted when a redeem request is created


```solidity
event RequestedRedeem(
    address indexed recipient, uint256 height, uint256 amount, uint256 maxRedeemableEth, uint32 id
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the redeem request|
|`height`|`uint256`|The height of the redeem request in LsETH|
|`amount`|`uint256`|The amount of the redeem request in LsETH|
|`maxRedeemableEth`|`uint256`|The maximum amount of eth that can be redeemed from this request|
|`id`|`uint32`|The id of the new redeem request|

### ReportedWithdrawal
Emitted when a withdrawal event is created


```solidity
event ReportedWithdrawal(uint256 height, uint256 amount, uint256 ethAmount, uint32 id);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`height`|`uint256`|The height of the withdrawal event in LsETH|
|`amount`|`uint256`|The amount of the withdrawal event in LsETH|
|`ethAmount`|`uint256`|The amount of eth to distrubute to claimers|
|`id`|`uint32`|The id of the withdrawal event|

### SatisfiedRedeemRequest
Emitted when a redeem request has been satisfied and filled (even partially) from a withdrawal event


```solidity
event SatisfiedRedeemRequest(
    uint32 indexed redeemRequestId,
    uint32 indexed withdrawalEventId,
    uint256 lsEthAmountSatisfied,
    uint256 ethAmountSatisfied,
    uint256 lsEthAmountRemaining,
    uint256 ethAmountExceeding
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemRequestId`|`uint32`|The id of the redeem request|
|`withdrawalEventId`|`uint32`|The id of the withdrawal event used to fill the request|
|`lsEthAmountSatisfied`|`uint256`|The amount of LsETH filled|
|`ethAmountSatisfied`|`uint256`|The amount of ETH filled|
|`lsEthAmountRemaining`|`uint256`|The amount of LsETH remaining|
|`ethAmountExceeding`|`uint256`|The amount of eth added to the exceeding buffer|

### ClaimedRedeemRequest
Emitted when a redeem request claim has been processed and matched at least once and funds are sent to the recipient


```solidity
event ClaimedRedeemRequest(
    uint32 indexed redeemRequestId,
    address indexed recipient,
    uint256 ethAmount,
    uint256 lsEthAmount,
    uint256 remainingLsEthAmount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemRequestId`|`uint32`|The id of the redeem request|
|`recipient`|`address`|The address receiving the redeem request funds|
|`ethAmount`|`uint256`|The amount of eth retrieved|
|`lsEthAmount`|`uint256`|The total amount of LsETH used to redeem the eth|
|`remainingLsEthAmount`|`uint256`|The amount of LsETH remaining|

### SetRedeemDemand
Emitted when the redeem demand is set


```solidity
event SetRedeemDemand(uint256 oldRedeemDemand, uint256 newRedeemDemand);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldRedeemDemand`|`uint256`|The old redeem demand|
|`newRedeemDemand`|`uint256`|The new redeem demand|

### SetRiver
Emitted when the River address is set


```solidity
event SetRiver(address river);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`river`|`address`|The new river address|

## Errors
### InvalidZeroAmount
Thrown When a zero value is provided


```solidity
error InvalidZeroAmount();
```

### TransferError
Thrown when a transfer error occured with LsETH


```solidity
error TransferError();
```

### IncompatibleArrayLengths
Thrown when the provided arrays don't have matching lengths


```solidity
error IncompatibleArrayLengths();
```

### RedeemRequestOutOfBounds
Thrown when the provided redeem request id is out of bounds


```solidity
error RedeemRequestOutOfBounds(uint256 id);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|The redeem request id|

### WithdrawalEventOutOfBounds
Thrown when the withdrawal request id if out of bounds


```solidity
error WithdrawalEventOutOfBounds(uint256 id);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|The withdrawal event id|

### RedeemRequestAlreadyClaimed
Thrown when	the redeem request id is already claimed


```solidity
error RedeemRequestAlreadyClaimed(uint256 id);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|The redeem request id|

### DoesNotMatch
Thrown when the redeem request and withdrawal event are not matching during claim


```solidity
error DoesNotMatch(uint256 redeemRequestId, uint256 withdrawalEventId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemRequestId`|`uint256`|The provided redeem request id|
|`withdrawalEventId`|`uint256`|The provided associated withdrawal event id|

### WithdrawalExceedsRedeemDemand
Thrown when the provided withdrawal event exceeds the redeem demand


```solidity
error WithdrawalExceedsRedeemDemand(uint256 withdrawalAmount, uint256 redeemDemand);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`withdrawalAmount`|`uint256`|The amount of the withdrawal event|
|`redeemDemand`|`uint256`|The current redeem demand|

### ClaimRedeemFailed
Thrown when the payment after a claim failed


```solidity
error ClaimRedeemFailed(address recipient, bytes rdata);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the payment|
|`rdata`|`bytes`|The revert data|

### ClaimRecipientIsDenied
Thrown when the claim recipient is denied


```solidity
error ClaimRecipientIsDenied();
```

### ClaimInitiatorIsDenied
Thrown when the claim initiator is denied


```solidity
error ClaimInitiatorIsDenied();
```

### RecipientIsDenied
Thrown when the recipient of redeemRequest is denied


```solidity
error RecipientIsDenied();
```

