# WithdrawV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/Withdraw.1.sol)

**Inherits:**
[IWithdrawV1](/contracts/src/interfaces/IWithdraw.1.sol/interface.IWithdrawV1.md), [Initializable](/contracts/src/Initializable.sol/contract.Initializable.md), [IProtocolVersion](/contracts/src/interfaces/IProtocolVersion.sol/interface.IProtocolVersion.md)

**Title:**
Withdraw (v1)

**Author:**
Alluvial Finance Inc.

This contract is in charge of holding the exit and skimming funds and allow river to pull these funds


## Functions
### onlyRiver


```solidity
modifier onlyRiver() ;
```

### initializeWithdrawV1


```solidity
function initializeWithdrawV1(address _river) external init(0);
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
function pullEth(uint256 _max) external onlyRiver;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_max`|`uint256`||


### _setRiver

Internal utility to set the river address


```solidity
function _setRiver(address _river) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_river`|`address`|The new river address|


### version

Retrieves the version of the contract


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Version of the contract|


