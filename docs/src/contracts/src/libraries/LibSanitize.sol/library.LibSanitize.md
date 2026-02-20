# LibSanitize
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/libraries/LibSanitize.sol)

**Title:**
Lib Sanitize

Utilities to sanitize input values


## Functions
### _notZeroAddress

Reverts if address is 0


```solidity
function _notZeroAddress(address _address) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|Address to check|


### _notEmptyString

Reverts if string is empty


```solidity
function _notEmptyString(string memory _string) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_string`|`string`|String to check|


### _validFee

Reverts if fee is invalid


```solidity
function _validFee(uint256 _fee) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_fee`|`uint256`|Fee to check|


