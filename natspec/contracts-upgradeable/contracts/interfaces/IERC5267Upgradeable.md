# IERC5267Upgradeable









## Methods

### eip712Domain

```solidity
function eip712Domain() external view returns (bytes1 fields, string name, string version, uint256 chainId, address verifyingContract, bytes32 salt, uint256[] extensions)
```



*returns the fields and values that describe the domain separator used by this contract for EIP-712 signature.*


#### Returns

| Name | Type | Description |
|---|---|---|
| fields | bytes1 | undefined |
| name | string | undefined |
| version | string | undefined |
| chainId | uint256 | undefined |
| verifyingContract | address | undefined |
| salt | bytes32 | undefined |
| extensions | uint256[] | undefined |



## Events

### EIP712DomainChanged

```solidity
event EIP712DomainChanged()
```



*MAY be emitted to signal that the domain could have changed.*




