# Variable Validator Balances (EIP-7251 / MaxEB Support)

## Motivation

EIP-7251 (MaxEB) allows Ethereum validators to operate with effective balances between 32 and 2048 ETH. CL rewards auto-compound into the validator's balance rather than being skimmed to the Withdraw contract. The protocol must shift from count-based accounting (validator count * 32 ETH) to direct ETH balance tracking.

## Design Decisions

- **Approach:** Replace all count-based state variables and accounting with ETH-denominated equivalents. No adapter layer or dual bookkeeping.
- **Deposit model:** Variable initial deposits (32-2048 ETH). The keeper provides pubkeys, BLS signatures, and amounts at deposit time (off-chain signing). The OperatorsRegistry no longer stores keys or signatures.
- **Exit model:** Exit demand is ETH-denominated. The keeper selects which validators to exit to cover the demand.
- **Oracle report:** Keeps `validatorsCount` as informational. All accounting uses `validatorsBalance` and a new `newlyActivatedDepositedBalance` field to track the pending deposit gap.

---

## 1. State Variable Changes

### Global State

| Current | Replacement | Type | Notes |
|---------|-------------|------|-------|
| `DepositedValidatorCount` | `DepositedBalance` | `uint256` | Cumulative ETH sent to the CL deposit contract |
| *(new)* | `ActivatedDepositedBalance` | `uint256` | Cumulative original deposit amounts for validators confirmed activated by oracle |
| `DEPOSIT_SIZE = 32 ether` | `MIN_DEPOSIT_SIZE = 32 ether`, `MAX_DEPOSIT_SIZE = 2048 ether` | constants | Bounds validation only |
| `CommittedBalance` | *(unchanged)* | `uint256` | Already ETH-denominated. Remove "must be multiple of 32" constraint |
| `CurrentValidatorExitsDemand` | `CurrentExitDemand` | `uint256` | ETH amount of exit demand (was validator count) |
| `TotalValidatorExitsRequested` | `TotalExitsRequested` | `uint256` | Cumulative ETH requested to exit (was validator count) |

### Operator Struct (new Operators.3.sol)

| Current Field | Replacement | Type | Notes |
|---------------|-------------|------|-------|
| `funded` | `fundedBalance` | `uint256` | Total ETH deposited for this operator |
| `requestedExits` | `requestedExitBalance` | `uint256` | Total ETH requested to exit for this operator |
| `active` | *(unchanged)* | `bool` | |
| `name` | *(unchanged)* | `string` | |
| `limit` | *(removed)* | | No longer relevant without key storage |

### Oracle Report Struct

| Field | Change |
|-------|--------|
| `validatorsCount` | Keep as informational — not used for accounting |
| `validatorsBalance` | Primary CL balance. Now includes auto-compounded rewards |
| `validatorsSkimmedBalance` | Still relevant for balance above 2048 ETH cap |
| `validatorsExitedBalance` | *(unchanged)* |
| `validatorsExitingBalance` | *(unchanged)* |
| `stoppedValidatorCountPerOperator` | Replace with `stoppedBalancePerOperator` (uint256[]) |
| *(new)* `newlyActivatedDepositedBalance` | Sum of original deposit amounts for validators activated since last report |

### Pending Deposit Gap

```
pendingBalance = DepositedBalance - ActivatedDepositedBalance
```

This replaces `(depositedValidatorCount - oracleValidatorsCount) * 32 ether`. It represents ETH deposited to the CL but not yet activated (in the activation queue).

---

## 2. Deposit Flow

The deposit flow changes from "look up keys in registry, deposit 32 ETH each" to "keeper provides keys + signatures + amounts, deposit variable ETH."

### New Deposit Struct and Function

```solidity
struct ValidatorDeposit {
    bytes pubkey;           // 48 bytes
    bytes signature;        // 96 bytes
    uint256 depositAmount;  // MIN_DEPOSIT_SIZE to MAX_DEPOSIT_SIZE
    uint256 operatorIndex;  // which operator this validator belongs to
}

function depositToConsensusLayer(ValidatorDeposit[] calldata _deposits) external;
```

### Validation Rules

- Caller must be keeper.
- Each `depositAmount` must be >= `MIN_DEPOSIT_SIZE` (32 ETH) and <= `MAX_DEPOSIT_SIZE` (2048 ETH).
- Each `depositAmount` must be a multiple of 1 gwei (CL requirement).
- Sum of all `depositAmount` values must not exceed `CommittedBalance`.
- Each `operatorIndex` must reference an active operator.

### State Updates Per Call

1. `CommittedBalance -= totalDepositedAmount`
2. `DepositedBalance += totalDepositedAmount`
3. `operator.fundedBalance += depositAmount` for each operator
4. Call the deposit contract with each `(pubkey, withdrawalCredentials, signature, depositAmount)`

### CommittedBalance Constraint Change

Remove the "must be multiple of 32 ETH" rounding in `_commitBalanceToDeposit`. Any amount can be committed. The keeper decides how to split it into deposits.

---

## 3. Oracle Report Processing & Asset Balance

### Report Validation

- **Activation tracking:** Each report includes `newlyActivatedDepositedBalance`. The contract adds this to `ActivatedDepositedBalance`. Validation: `ActivatedDepositedBalance + newlyActivatedDepositedBalance <= DepositedBalance`.
- **Balance sanity checks:** The `ReportBounds` system operates on `validatorsBalance` deltas directly. The change in `validatorsBalance` between reports must be within configurable limits (accounting for rewards growth, slashing, exits).
- **`validatorsCount`** is stored but not used in accounting math. Informational only.

### _assetBalance() Formula

```solidity
function _assetBalance() internal view returns (uint256) {
    StoredConsensusLayerReport storage storedReport = LastConsensusLayerReport.get();
    uint256 pendingBalance = DepositedBalance.get() - ActivatedDepositedBalance.get();

    return storedReport.validatorsBalance
        + pendingBalance
        + BalanceToDeposit.get()
        + CommittedBalance.get()
        + BalanceToRedeem.get();
}
```

No `DEPOSIT_SIZE` multiplication. Purely additive ETH balances.

### CL Rewards Accounting

- Between oracle reports, `validatorsBalance` is stale. CL rewards that have auto-compounded since the last report are not reflected until the next report. The exchange rate updates discretely per report, same as today.
- `validatorsSkimmedBalance` still captures ETH skimmed above 2048 ETH to the Withdraw contract. Pulled into `BalanceToRedeem` or `BalanceToDeposit` during report processing, same as today.

---

## 4. Exit Flow

The exit system shifts from "request N validators to exit" to "request X ETH worth of exits."

### State Changes

| Current | Replacement |
|---------|-------------|
| `CurrentValidatorExitsDemand` (count) | `CurrentExitDemand` (wei) |
| `TotalValidatorExitsRequested` (count) | `TotalExitsRequested` (wei) |
| `operator.requestedExits` (count) | `operator.requestedExitBalance` (wei) |
| `stoppedValidatorCountPerOperator` (uint32[]) | `stoppedBalancePerOperator` (uint256[]) |

### Exit Demand Calculation

In `_requestExitsBasedOnRedeemDemandAfterRebalancings`:

```
redeemDemandInEth = _balanceFromShares(redeemDemand)
exitingBalance = storedReport.validatorsExitingBalance
preExitingBalance = TotalExitsRequested - totalStoppedBalance

if redeemDemandInEth > availableBalance + exitingBalance + preExitingBalance:
    newExitDemand = redeemDemandInEth - availableBalance - exitingBalance - preExitingBalance
    CurrentExitDemand.set(newExitDemand)
```

No division by `DEPOSIT_SIZE`, no ceiling math. The demand is pure ETH.

### requestValidatorExits()

```solidity
struct ExitAllocation {
    uint256 operatorIndex;
    uint256 exitBalance;    // ETH amount to exit from this operator
}

function requestValidatorExits(ExitAllocation[] calldata _allocations) external;
```

Validation:
- Sum of `exitBalance` values must not exceed `CurrentExitDemand`.
- Each `exitBalance` must not exceed operator's available balance: `operator.fundedBalance - operator.requestedExitBalance`.
- Operator must be active.
- Allocations must be sorted by operator index, strictly ascending.

State updates:
- `operator.requestedExitBalance += exitBalance`
- `TotalExitsRequested += totalExitBalance`
- `CurrentExitDemand -= totalExitBalance`

### Stopped Balance Reporting

The oracle's `stoppedBalancePerOperator` array replaces `stoppedValidatorCountPerOperator`. The `_setStoppedBalances` function applies the same monotonically-increasing validation, in ETH. If `stoppedBalance > operator.requestedExitBalance`, unsolicited exits are detected (same logic, different unit).

---

## 5. Migration

Runs once during `initializeVX()` on upgrade. All existing validators were deposited at exactly 32 ETH, so the count-to-ETH conversion is lossless.

### Migration Logic

```solidity
// Global state
DepositedBalance.set(DepositedValidatorCount.get() * 32 ether);
ActivatedDepositedBalance.set(lastReport.validatorsCount * 32 ether);

// Exit demand
CurrentExitDemand.set(CurrentValidatorExitsDemand.get() * 32 ether);
TotalExitsRequested.set(TotalValidatorExitsRequested.get() * 32 ether);

// Per-operator state
for each operator:
    operator.fundedBalance = operator.funded * 32 ether;
    operator.requestedExitBalance = operator.requestedExits * 32 ether;
```

### Deprecated State Variables

The following storage slots are preserved but no longer written:
- `DepositedValidatorCount`
- `CurrentValidatorExitsDemand`
- `TotalValidatorExitsRequested`
- `ValidatorKeys` storage

### Storage Layout

The operator struct changes from `Operators.2.sol` (uint32 fields) to `Operators.3.sol` (uint256 fields). This follows the existing migration pattern.

### Oracle Coordination

The first oracle report after upgrade must use the new format (`stoppedBalancePerOperator`, `newlyActivatedDepositedBalance`). The off-chain oracle must be updated in lockstep with the contract upgrade. The `initializeVX` migration converts the last stored report's stopped counts to stopped balances (multiply by 32 ETH).

---

## 6. OperatorsRegistry Simplification

### Removed Functionality

- `addValidators()` — operators no longer submit keys to the registry
- `removeValidators()` — no keys to remove
- `pickNextValidatorsToDeposit()` — replaced by `depositToConsensusLayer()` on River/ConsensusLayerDepositManager
- `ValidatorKeys` storage library — unused
- `limit` field on operator struct — no key-count limit needed

### Retained Functionality

- Operator management: `addOperator`, `setOperatorStatus`, `setOperatorName`
- Balance tracking: `fundedBalance`, `requestedExitBalance` per operator
- Exit allocation: `requestValidatorExits()` (ETH-denominated)
- Stopped balance reporting: `_setStoppedBalances()` (called during oracle report)
- Admin/governance functions

The registry becomes an operator ledger. It tracks who operators are, how much ETH is deposited to each, and exit accounting. It no longer manages validator keys.

---

## Files Impacted

| File | Change Scope |
|------|-------------|
| `River.1.sol` | `_assetBalance()`, `_commitBalanceToDeposit()`, `_requestExitsBasedOnRedeemDemandAfterRebalancings()`, `_reportWithdrawToRedeemManager()` |
| `ConsensusLayerDepositManager.1.sol` | Replace deposit function, remove `DEPOSIT_SIZE` division, accept `ValidatorDeposit[]` |
| `OracleManager.1.sol` | Report validation, `_setStoppedBalances()`, activation tracking |
| `OperatorsRegistry.1.sol` | Remove key storage functions, update exit functions to ETH, simplify |
| `Operators.3.sol` *(new)* | New operator struct with uint256 balance fields |
| `DepositedBalance.sol` *(new)* | State library replacing `DepositedValidatorCount` |
| `ActivatedDepositedBalance.sol` *(new)* | State library for oracle-confirmed activated deposits |
| `CurrentExitDemand.sol` *(new)* | State library replacing `CurrentValidatorExitsDemand` |
| `TotalExitsRequested.sol` *(new)* | State library replacing `TotalValidatorExitsRequested` |
| `IOracleManager.1.sol` | Updated report structs |
| `IOperatorRegistry.1.sol` | Updated interface (remove key functions, ETH-denominated exits) |
| `IConsensusLayerDepositManager.1.sol` | Updated deposit interface |
| `IRiver.1.sol` | Updated interface |
| `SharesManager.1.sol` | No changes needed — already uses `_assetBalance()` abstractly |
| `RedeemManager.1.sol` | No changes needed — already works in ETH/shares |
