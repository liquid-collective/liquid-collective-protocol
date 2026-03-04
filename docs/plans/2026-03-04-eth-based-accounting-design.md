# ETH-Based Accounting Design

## Motivation

EIP-7251 (MaxEB) allows validators to have effective balances beyond 32 ETH (up to 2048 ETH). The current accounting system calculates in-flight balance as `(depositedValidatorCount - clValidatorCount) * 32 ETH`, which breaks when validators can be funded with variable amounts.

## Current System

The total underlying supply backing LsETH is computed in `_assetBalance()` (River.1.sol:392):

```
total = validatorsBalance + balanceToDeposit + committedBalance + balanceToRedeem
      + max(0, (depositedValidatorCount - clValidatorCount) * DEPOSIT_SIZE)
```

Two validator counts are maintained:
- `DepositedValidatorCount`: incremented on-chain when validators are deposited to beacon chain
- `validatorsCount` (in oracle report): how many validators the oracle sees as activated

Their difference, multiplied by 32 ETH, synthesizes the balance of validators in flight.

## New System

### Core Formula

Replace the validator count difference with direct ETH tracking:

```
total = validatorsBalance + balanceToDeposit + committedBalance + balanceToRedeem
      + max(0, totalDepositedETH - (validatorsBalance + exitedBalance + skimmedBalance))
```

Where:
- `totalDepositedETH`: cumulative ETH sent to the deposit contract (new state variable)
- `validatorsBalance + exitedBalance + skimmedBalance`: total ETH the oracle has accounted for

The difference is what's still in flight (deposited but not yet visible to the oracle).

### New State Variable

**`TotalDepositedETH`** (contracts/src/state/river/TotalDepositedETH.sol)
- `uint256` in storage, following existing state variable patterns
- Incremented by the actual deposit amount each time a validator is deposited
- Cumulative, never decremented

### Deposit Flow Changes

**ConsensusLayerDepositManager.1.sol:**

1. `OperatorAllocation` struct gains a `uint256[] depositAmounts` field (one amount per validator in the allocation)
2. `_depositValidator()` accepts a `uint256 _depositAmount` parameter instead of using hardcoded `DEPOSIT_SIZE`
3. After depositing a batch:
   - `committedBalance -= sum(all deposit amounts)`
   - `TotalDepositedETH += sum(all deposit amounts)`
   - `DepositedValidatorCount += receivedPublicKeyCount` (kept for informational purposes)
4. Validation: each deposit amount must be >= 1 ether and a multiple of 1 gwei (Ethereum deposit contract requirements)
5. The `maxDepositableCount` check changes to verify total requested ETH <= `committedBalance`

**OperatorAllocation struct (IOperatorRegistry.1.sol):**
```solidity
struct OperatorAllocation {
    uint256 operatorIndex;
    uint256 validatorCount;
    uint256[] depositAmounts; // length == validatorCount
}
```

### Oracle Report

No structural changes to the oracle report. The existing fields (`validatorsBalance`, `validatorsExitedBalance`, `validatorsSkimmedBalance`, `validatorsCount`) are sufficient.

The `validatorsCount` validation in `OracleManager.setConsensusLayerData()` is kept as a sanity check (oracle cannot report more validators than were deposited).

### What Stays Unchanged

- Oracle report structure (no new fields)
- `DepositedValidatorCount` (kept for informational use, removed from `_assetBalance()`)
- Share math in `SharesManager` (calls `_assetBalance()` which handles the change)
- Redeem flow, EL fee recipient, coverage fund
- APR bounds checking in oracle reporting

## Migration

On upgrade, `TotalDepositedETH` must be initialized to produce the exact same `_assetBalance()` as the old formula.

**Derivation:** Setting `inFlight_old == inFlight_new`:
```
(depositedCount - clCount) * 32 == totalDepositedETH - (validatorsBalance + exitedBalance + skimmedBalance)
```

Solving:
```
totalDepositedETH = (depositedCount - clCount) * 32
                  + validatorsBalance + exitedBalance + skimmedBalance
```

**Migration code:**
```solidity
StoredConsensusLayerReport storage report = LastConsensusLayerReport.get();
uint256 totalDepositedETH =
    (DepositedValidatorCount.get() - report.validatorsCount) * 32 ether
    + report.validatorsBalance
    + report.validatorsExitedBalance
    + report.validatorsSkimmedBalance;
TotalDepositedETH.set(totalDepositedETH);
```

This guarantees `_assetBalance()` returns the identical value before and after upgrade.

## Files Changed

| File | Change |
|------|--------|
| `state/river/TotalDepositedETH.sol` | NEW state variable |
| `River.1.sol` | New `_assetBalance()` formula + migration initializer |
| `ConsensusLayerDepositManager.1.sol` | Variable deposit amounts, increment `TotalDepositedETH` |
| `interfaces/IOperatorRegistry.1.sol` | Add `depositAmounts` to `OperatorAllocation` |
| `OperatorsRegistry.1.sol` | Pass through deposit amounts in `_getNextValidators()` |
| `OracleManager.1.sol` | No formula changes (calls `_assetBalance()`) |
| `interfaces/components/IOracleManager.1.sol` | No changes |
