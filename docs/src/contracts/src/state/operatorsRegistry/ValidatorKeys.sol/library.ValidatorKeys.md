# ValidatorKeys
[Git Source](https://github.com/liquid-collective/liquid-collective-protocol/blob/15c3aa6bd08000650f7da3ad4e5147502603ad9b/contracts/src/state/operatorsRegistry/ValidatorKeys.sol)

**Title:**
Validator Keys Storage

Utility to manage the validator keys in storage


## State Variables
### VALIDATOR_KEYS_SLOT
Storage slot of the Validator Keys


```solidity
bytes32 internal constant VALIDATOR_KEYS_SLOT = bytes32(uint256(keccak256("river.state.validatorKeys")) - 1)
```


### PUBLIC_KEY_LENGTH
Length in bytes of a BLS Public Key used for validator deposits


```solidity
uint256 internal constant PUBLIC_KEY_LENGTH = 48
```


### SIGNATURE_LENGTH
Length in bytes of a BLS Signature used for validator deposits


```solidity
uint256 internal constant SIGNATURE_LENGTH = 96
```


## Functions
### get

Retrieve the Validator Key of an operator at a specific index


```solidity
function get(uint256 _operatorIndex, uint256 _idx)
    internal
    view
    returns (bytes memory publicKey, bytes memory signature);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operatorIndex`|`uint256`|The operator index|
|`_idx`|`uint256`|the Validator Key index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKey`|`bytes`|The Validator Key public key|
|`signature`|`bytes`|The Validator Key signature|


### getRaw

Retrieve the raw concatenated Validator Keys


```solidity
function getRaw(uint256 _operatorIndex, uint256 _idx) internal view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operatorIndex`|`uint256`|The operator index|
|`_idx`|`uint256`|The Validator Key index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The concatenated public key and signature|


### getKeys

Retrieve multiple keys of an operator starting at an index


```solidity
function getKeys(uint256 _operatorIndex, uint256 _startIdx, uint256 _amount)
    internal
    view
    returns (bytes[] memory publicKeys, bytes[] memory signatures);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operatorIndex`|`uint256`|The operator index|
|`_startIdx`|`uint256`|The starting index to retrieve the keys from|
|`_amount`|`uint256`|The amount of keys to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKeys`|`bytes[]`|The public keys retrieved|
|`signatures`|`bytes[]`|The signatures associated with the public keys|


### set

Set the concatenated Validator Keys at an index for an operator


```solidity
function set(uint256 _operatorIndex, uint256 _idx, bytes memory _publicKeyAndSignature) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operatorIndex`|`uint256`|The operator index|
|`_idx`|`uint256`|The key index to write on|
|`_publicKeyAndSignature`|`bytes`|The concatenated Validator Keys|


## Errors
### InvalidPublicKey
The provided public key is not matching the expected length


```solidity
error InvalidPublicKey();
```

### InvalidSignature
The provided signature is not matching the expected length


```solidity
error InvalidSignature();
```

## Structs
### Slot
Structure of the Validator Keys in storage


```solidity
struct Slot {
    /// @custom:attribute The mapping from operator index to key index to key value
    mapping(uint256 => mapping(uint256 => bytes)) value;
}
```

