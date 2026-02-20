# ELFeeRecipientV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/ELFeeRecipient.1.sol)

**Inherits:**
[Initializable](/contracts/src/Initializable.sol/contract.Initializable.md), [IELFeeRecipientV1](/contracts/src/interfaces/IELFeeRecipient.1.sol/interface.IELFeeRecipientV1.md), [IProtocolVersion](/contracts/src/interfaces/IProtocolVersion.sol/interface.IProtocolVersion.md)

**Title:**
Execution Layer Fee Recipient (v1)

**Author:**
Alluvial Finance Inc.

This contract receives all the execution layer fees from the proposed blocks + bribes


## Functions
### initELFeeRecipientV1

Initialize the fee recipient with the required arguments


```solidity
function initELFeeRecipientV1(address _riverAddress) external init(0);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_riverAddress`|`address`|Address of River|


### pullELFees

Pulls ETH to the River contract

Only callable by the River contract


```solidity
function pullELFees(uint256 _maxAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxAmount`|`uint256`|The maximum amount to pull into the system|


### receive

Ether receiver


```solidity
receive() external payable;
```

### fallback

Invalid fallback detector


```solidity
fallback() external payable;
```

### version


```solidity
function version() external pure returns (string memory);
```

