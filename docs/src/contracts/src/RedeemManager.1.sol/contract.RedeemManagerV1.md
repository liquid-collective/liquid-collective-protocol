# RedeemManagerV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/RedeemManager.1.sol)

**Inherits:**
[Initializable](/contracts/src/Initializable.sol/contract.Initializable.md), [IRedeemManagerV1](/contracts/src/interfaces/IRedeemManager.1.sol/interface.IRedeemManagerV1.md), [IProtocolVersion](/contracts/src/interfaces/IProtocolVersion.sol/interface.IProtocolVersion.md)

**Title:**
Redeem Manager (v1)

**Author:**
Alluvial Finance Inc.

This contract handles the redeem requests of all users


## State Variables
### RESOLVE_UNSATISFIED
Value returned when resolving a redeem request that is unsatisfied


```solidity
int64 internal constant RESOLVE_UNSATISFIED = -1
```


### RESOLVE_OUT_OF_BOUNDS
Value returned when resolving a redeem request that is out of bounds


```solidity
int64 internal constant RESOLVE_OUT_OF_BOUNDS = -2
```


### RESOLVE_FULLY_CLAIMED
Value returned when resolving a redeem request that is already claimed


```solidity
int64 internal constant RESOLVE_FULLY_CLAIMED = -3
```


### CLAIM_FULLY_CLAIMED
Status value returned when fully claiming a redeem request


```solidity
uint8 internal constant CLAIM_FULLY_CLAIMED = 0
```


### CLAIM_PARTIALLY_CLAIMED
Status value returned when partially claiming a redeem request


```solidity
uint8 internal constant CLAIM_PARTIALLY_CLAIMED = 1
```


### CLAIM_SKIPPED
Status value returned when a redeem request is already claimed and skipped during a claim


```solidity
uint8 internal constant CLAIM_SKIPPED = 2
```


## Functions
### onlyRiver


```solidity
modifier onlyRiver() ;
```

### onlyRedeemerOrRiver


```solidity
modifier onlyRedeemerOrRiver() ;
```

### onlyRedeemer


```solidity
modifier onlyRedeemer() ;
```

### initializeRedeemManagerV1


```solidity
function initializeRedeemManagerV1(address _river) external init(0);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_river`|`address`|The address of the River contract|


### initializeRedeemManagerV1_2


```solidity
function initializeRedeemManagerV1_2() external init(1);
```

### _redeemQueueMigrationV1_2


```solidity
function _redeemQueueMigrationV1_2() internal;
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
function getRedeemRequestDetails(uint32 _redeemRequestId)
    external
    view
    returns (RedeemQueueV2.RedeemRequest memory);
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
function requestRedeem(uint256 _lsETHAmount, address _recipient)
    external
    onlyRedeemerOrRiver
    returns (uint32 redeemRequestId);
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
function requestRedeem(uint256 _lsETHAmount) external onlyRedeemer returns (uint32 redeemRequestId);
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
    uint32[] calldata redeemRequestIds,
    uint32[] calldata withdrawalEventIds,
    bool skipAlreadyClaimed,
    uint16 _depth
) external returns (uint8[] memory claimStatuses);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemRequestIds`|`uint32[]`||
|`withdrawalEventIds`|`uint32[]`||
|`skipAlreadyClaimed`|`bool`||
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
function reportWithdraw(uint256 _lsETHWithdrawable) external payable onlyRiver;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lsETHWithdrawable`|`uint256`|The amount of LsETH that can be redeemed due to this new withdraw event|


### pullExceedingEth

Pulls exceeding buffer eth


```solidity
function pullExceedingEth(uint256 _max) external onlyRiver;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_max`|`uint256`|The maximum amount that should be pulled|


### _castedRiver

Internal utility to load and cast the River address


```solidity
function _castedRiver() internal view returns (IRiverV1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IRiverV1`|The casted river address|


### _isMatch

Internal utility to verify if a redeem request and a withdrawal event are matching


```solidity
function _isMatch(
    RedeemQueueV2.RedeemRequest memory _redeemRequest,
    WithdrawalStack.WithdrawalEvent memory _withdrawalEvent
) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequest`|`RedeemQueueV2.RedeemRequest`|The loaded redeem request|
|`_withdrawalEvent`|`WithdrawalStack.WithdrawalEvent`|The load withdrawal event|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if matching|


### _performDichotomicResolution

Internal utility to perform a dichotomic search of the withdrawal event to use to claim the redeem request


```solidity
function _performDichotomicResolution(RedeemQueueV2.RedeemRequest memory _redeemRequest)
    internal
    view
    returns (int64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequest`|`RedeemQueueV2.RedeemRequest`|The redeem request to resolve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int64`|The matching withdrawal event|


### _resolveRedeemRequestId

Internal utility to resolve a redeem request and retrieve its satisfying withdrawal event id, or identify possible errors


```solidity
function _resolveRedeemRequestId(
    uint32 _redeemRequestId,
    WithdrawalStack.WithdrawalEvent memory _lastWithdrawalEvent
) internal view returns (int64 withdrawalEventId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequestId`|`uint32`|The redeem request id|
|`_lastWithdrawalEvent`|`WithdrawalStack.WithdrawalEvent`|The last withdrawal event loaded in memory|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`withdrawalEventId`|`int64`|The id of the withdrawal event matching the redeem request or error code|


### _requestRedeem

Perform a new redeem request for the specified recipient


```solidity
function _requestRedeem(uint256 _lsETHAmount, address _recipient) internal returns (uint32 redeemRequestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lsETHAmount`|`uint256`|The amount of LsETH to redeem|
|`_recipient`|`address`|The recipient owning the request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`redeemRequestId`|`uint32`|The id of the newly created redeem request|


### _saveRedeemRequest

Internal utility to save a redeem request to storage


```solidity
function _saveRedeemRequest(ClaimRedeemRequestParameters memory _params) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_params`|`ClaimRedeemRequestParameters`|The parameters of the claim redeem request call|


### _claimRedeemRequest

Internal utility to claim a redeem request if possible

Will call itself recursively if the redeem requests overflows its matching withdrawal event


```solidity
function _claimRedeemRequest(ClaimRedeemRequestParameters memory _params) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_params`|`ClaimRedeemRequestParameters`|The parameters of the claim redeem request call|


### _claimRedeemRequests

Internal utility to claim several redeem requests at once


```solidity
function _claimRedeemRequests(
    uint32[] calldata _redeemRequestIds,
    uint32[] calldata _withdrawalEventIds,
    bool _skipAlreadyClaimed,
    uint16 _depth
) internal returns (uint8[] memory claimStatuses);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_redeemRequestIds`|`uint32[]`|The list of redeem requests to claim|
|`_withdrawalEventIds`|`uint32[]`|The list of withdrawal events to use for each redeem request. Should have the same length.|
|`_skipAlreadyClaimed`|`bool`|True if the system should skip redeem requests already claimed, otherwise will revert|
|`_depth`|`uint16`|The depth of the recursion to use when claiming a redeem request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`claimStatuses`|`uint8[]`|The claim statuses for each redeem request|


### _setRedeemDemand

Internal utility to set the redeem demand


```solidity
function _setRedeemDemand(uint256 _newValue) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newValue`|`uint256`|The new value to set|


### version


```solidity
function version() external pure returns (string memory);
```

## Structs
### ClaimRedeemRequestParameters
Internal structure used to optimize stack usage in _claimRedeemRequest


```solidity
struct ClaimRedeemRequestParameters {
    /// @custom:attribute The structure of the redeem request to claim
    RedeemQueueV2.RedeemRequest redeemRequest;
    /// @custom:attribute The structure of the withdrawal event to use to claim the redeem request
    WithdrawalStack.WithdrawalEvent withdrawalEvent;
    /// @custom:attribute The id of the redeem request to claim
    uint32 redeemRequestId;
    /// @custom:attribute The id of the withdrawal event to use to claim the redeem request
    uint32 withdrawalEventId;
    /// @custom:attribute The count of withdrawal events
    uint32 withdrawalEventCount;
    /// @custom:attribute The current depth of the recursive call
    uint16 depth;
    /// @custom:attribute The amount of LsETH redeemed/matched, needs to be reset to 0 for each call/before calling the recursive function
    uint256 lsETHAmount;
    /// @custom:attribute The amount of eth redeemed/matched, needs to be rest to 0 for each call/before calling the recursive function
    uint256 ethAmount;
}
```

### ClaimRedeemRequestInternalVariables
Internal structure used to optimize stack usage in _claimRedeemRequest


```solidity
struct ClaimRedeemRequestInternalVariables {
    /// @custom:attribute The eth amount claimed by the user
    uint256 ethAmount;
    /// @custom:attribute The amount of LsETH matched during this step
    uint256 matchingAmount;
    /// @custom:attribute The amount of eth redirected to the exceeding eth buffer
    uint256 exceedingEthAmount;
}
```

