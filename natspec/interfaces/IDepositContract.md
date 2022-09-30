# IDepositContract



> Deposit Contract Interface

This interface exposes methods to perform validator deposits



## Methods

### deposit

```solidity
function deposit(bytes pubkey, bytes withdrawalCredentials, bytes signature, bytes32 depositDataRoot) external payable
```

Official deposit method to activate a validator on the consensus layer



#### Parameters

| Name | Type | Description |
|---|---|---|
| pubkey | bytes | The 48 bytes long BLS Public key representing the validator |
| withdrawalCredentials | bytes | The 32 bytes long withdrawal credentials, configures the withdrawal recipient |
| signature | bytes | The 96 bytes long BLS Signature performed by the pubkey&#39;s private key |
| depositDataRoot | bytes32 | The root hash of the whole deposit data structure |




