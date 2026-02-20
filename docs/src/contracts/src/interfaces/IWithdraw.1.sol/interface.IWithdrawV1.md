# IWithdrawV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/IWithdraw.1.sol)

**Title:**
Withdraw Interface (V1)

**Author:**
Alluvial Finance Inc.

This contract is in charge of holding the exit and skimming funds and allow river to pull these funds


## Functions
### initializeWithdrawV1


```solidity
function initializeWithdrawV1(address _river) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_river`|`address`|The address of the River contract|


### getCredentials

Retrieve the withdrawal credentials to use


```solidity
function getCredentials() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The withdrawal credentials|


### getRiver

Retrieve the linked River address


```solidity
function getRiver() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The River address|


### pullEth

Callable by River, sends the specified amount of ETH to River


```solidity
function pullEth(uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|The amount to pull|


## Events
### SetRiver
Emitted when the linked River address is changed


```solidity
event SetRiver(address river);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`river`|`address`|The new River address|

