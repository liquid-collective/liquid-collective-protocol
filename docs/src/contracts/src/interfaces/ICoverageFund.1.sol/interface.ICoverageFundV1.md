# ICoverageFundV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/interfaces/ICoverageFund.1.sol)

**Title:**
Coverage Fund Interface (v1)

**Author:**
Alluvial Finance Inc.

This interface exposes methods to receive donations for the slashing coverage fund and pull the funds into river


## Functions
### initCoverageFundV1

Initialize the coverage fund with the required arguments


```solidity
function initCoverageFundV1(address _riverAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_riverAddress`|`address`|Address of River|


### pullCoverageFunds

Pulls ETH into the River contract

Only callable by the River contract


```solidity
function pullCoverageFunds(uint256 _maxAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxAmount`|`uint256`|The maximum amount to pull into the system|


### donate

Donates ETH to the coverage fund contract


```solidity
function donate() external payable;
```

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

## Events
### SetRiver
The storage river address has changed


```solidity
event SetRiver(address indexed river);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`river`|`address`|The new river address|

### Donate
A donation has been made to the coverage fund


```solidity
event Donate(address indexed donator, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`donator`|`address`|Address that performed the donation|
|`amount`|`uint256`|The amount donated|

## Errors
### InvalidCall
The fallback or receive callback has been triggered


```solidity
error InvalidCall();
```

### EmptyDonation
A donation with 0 ETH has been performed


```solidity
error EmptyDonation();
```

