# CoverageFundV1
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/CoverageFund.1.sol)

**Inherits:**
[Initializable](/contracts/src/Initializable.sol/contract.Initializable.md), [ICoverageFundV1](/contracts/src/interfaces/ICoverageFund.1.sol/interface.ICoverageFundV1.md), [IProtocolVersion](/contracts/src/interfaces/IProtocolVersion.sol/interface.IProtocolVersion.md)

**Title:**
Coverage Fund (v1)

**Author:**
Alluvial Finance Inc.

This contract receive donations for the slashing coverage fund and pull the funds into river

This contract acts as a temporary buffer for funds that should be pulled in case of a loss of money on the consensus layer due to slashing events.

There is no fee taken on these funds, they are entirely distributed to the LsETH holders, and no shares will get minted.

Funds will be distributed by increasing the underlying value of every LsETH share.

The fund will be called on every report and if eth is available in the contract, River will attempt to pull as much

ETH as possible. This maximum is defined by the upper bound allowed by the Oracle. This means that it might take multiple

reports for funds to be pulled entirely into the system due to this upper bound, ensuring a lower secondary market impact.

The value provided to this contract is computed off-chain and provided manually by Alluvial or any authorized insurance entity.

The Coverage funds are pulled upon an oracle report, after the ELFees have been pulled in the system, if there is a margin left

before crossing the upper bound. The reason behind this is to favor the revenue stream, that depends on market and network usage, while

the coverage fund will be pulled after the revenue stream, and there won't be any commission on the eth pulled.

Once a Slashing event occurs, the team will do its best to inject the recovery funds in at maximum 365 days

The entities allowed to donate are selected by the team. It will mainly be treasury entities or insurance protocols able to fill this coverage fund properly.


## Functions
### initCoverageFundV1

Initialize the coverage fund with the required arguments


```solidity
function initCoverageFundV1(address _riverAddress) external init(0);
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

### version


```solidity
function version() external pure returns (string memory);
```

