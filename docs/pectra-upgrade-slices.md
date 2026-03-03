---
shaping: true
---

# Pectra Upgrade — Slices

Based on [Shape A](pectra-upgrade-shaping.md): Consolidation Buffer + EL-Triggered Partial Exits.

## Dependency Graph

```
A1 (buffer) ──┐
A2 (assetBalance) ──┤
                    ├──→ V1: Consolidation
A3 (entry point) ──┤
A4 (oracle recon) ──┤
A5 (minting) ──────┘
                         A8 (insolvency) ──→ V3: Protection
A6 (partial exits) ──┐
A7 (keeper strategy) ┘──→ V2: Partial Exits
```

V1 and V2 are **independent** (no shared dependency beyond existing contracts). V3 depends on V1.

---

## V1: Validator Consolidation (Happy Path)

**Parts:** A1, A2, A3, A4, A5

**Demo:** User requests consolidation → keeper executes → LsETH minted immediately → oracle report reconciles buffer → conversion rate unchanged.

### Contracts touched

| Contract | What changes |
|----------|-------------|
| **River.1.sol** | `requestConsolidation()`, `executeConsolidation()`, modified `_assetBalance()` with `PendingConsolidationBalance`, consolidation reconciliation in `setConsensusLayerData` |
| **Allowlist.1.sol** | New `CONSOLIDATION_MASK = 0x8` |
| **IOracleManager.1.sol** | `ConsensusLayerReport` + `StoredConsensusLayerReport` extended with `validatorsConsolidatedBalance` |
| **OracleManager.1.sol** | Reconciliation logic: `PendingConsolidationBalance -= consolidatedDelta` |
| **State (new)** | `PendingConsolidationBalance.sol`, `ConsolidationRequests.sol` |

### Non-UI Affordances

| Affordance | Type | Wires Out |
|------------|------|-----------|
| `ConsolidationRequest` struct | Data store | Stored in `ConsolidationRequests` array |
| `consolidationRequestBySource` mapping | Index | `bytes32 sourcePubkeyHash → uint256 requestId` |
| `PendingConsolidationBalance` | Storage variable | Read by `_assetBalance()`, written by `executeConsolidation()` and `setConsensusLayerData` |
| `requestConsolidation(sourcePubkey, targetPubkey)` | External fn (user) | → allowlist check → store request → emit event |
| `executeConsolidation(requestId, expectedBalance)` | External fn (keeper) | → store expectedBalance → `PendingConsolidationBalance += amount` → `_mintShares()` → submit CL consolidation request |
| `_reconcileConsolidations(consolidatedDelta)` | Internal fn | → `PendingConsolidationBalance -= delta` → update request statuses |
| `validatorsConsolidatedBalance` | Oracle report field | Cumulative, non-decreasing. Delta used in reconciliation. |

### Key flow

```
User → requestConsolidation(srcPubkey, tgtPubkey)
  ├─ Allowlist: onlyAllowed(msg.sender, CONSOLIDATION_MASK)
  ├─ Validate: targetPubkey ∈ OperatorsRegistry
  ├─ Store: ConsolidationRequest{src, tgt, recipient, status: REQUESTED}
  └─ Emit: ConsolidationRequested

Keeper → executeConsolidation(requestId, expectedBalance)
  ├─ OnlyKeeper
  ├─ Store: request.expectedBalance = expectedBalance, status = PENDING
  ├─ Buffer: PendingConsolidationBalance += expectedBalance
  ├─ Mint: _mintShares(request.recipient, expectedBalance)
  ├─ CL: submit consolidation request to system contract
  └─ Emit: ConsolidationExecuted

Oracle → setConsensusLayerData(report)
  ├─ ... existing flow ...
  ├─ consolidatedDelta = report.validatorsConsolidatedBalance - last.validatorsConsolidatedBalance
  ├─ PendingConsolidationBalance -= min(consolidatedDelta, PendingConsolidationBalance)
  ├─ Store: last.validatorsConsolidatedBalance = report.validatorsConsolidatedBalance
  └─ ... postReportUnderlyingBalance = _assetBalance() (consolidation cancels out) ...
```

---

## V2: Partial Exits via EIP-7002

**Parts:** A6, A7

**Demo:** Redeem demand exceeds available ETH → keeper triggers partial exits on validators with excess > 32 ETH → funds arrive at Withdraw → oracle reports → `BalanceToRedeem` increases → redemption satisfied faster than full exit.

### Contracts touched

| Contract | What changes |
|----------|-------------|
| **Withdraw.1.sol** | New `requestWithdrawal(pubkey, amountInGwei)` — calls EIP-7002 system contract |
| **River.1.sol** | New `requestExits(ExitRequest)` replacing/extending current exit flow. Modified `_requestExitsBasedOnRedeemDemandAfterRebalancings()` to account for `PendingPartialExitBalance`. Partial exit reconciliation in `setConsensusLayerData`. |
| **IOracleManager.1.sol** | `ConsensusLayerReport` + `StoredConsensusLayerReport` extended with `validatorsPartiallyExitedBalance` |
| **OracleManager.1.sol** | Reconciliation logic: `PendingPartialExitBalance -= partialExitDelta` |
| **State (new)** | `PendingPartialExitBalance.sol` |

### Non-UI Affordances

| Affordance | Type | Wires Out |
|------------|------|-----------|
| `PendingPartialExitBalance` | Storage variable | Read by exit demand calc, written by `requestExits()` and `setConsensusLayerData` |
| `requestWithdrawal(pubkey, amountInGwei)` | External fn on Withdraw (River-only) | → encode request → call EIP-7002 system contract with fee |
| `requestExits(ExitRequest)` | External fn on River (keeper) | → route partial exits through Withdraw → route full exits through OperatorsRegistry |
| `PartialExitRequest` struct | Calldata | `{pubkey, amountInGwei}` |
| `ExitRequest` struct | Calldata | `{PartialExitRequest[], OperatorAllocation[]}` |
| `validatorsPartiallyExitedBalance` | Oracle report field | Cumulative, non-decreasing. Delta used in reconciliation. |

### Key flow

```
Keeper → requestExits({partialExits, fullExits})
  ├─ OnlyKeeper
  ├─ For each partial exit:
  │   ├─ Withdraw.requestWithdrawal(pubkey, amountInGwei)
  │   │   └─ EIP-7002 system contract call
  │   └─ PendingPartialExitBalance += amount
  ├─ For full exits:
  │   └─ OperatorsRegistry.requestValidatorExits(fullExits)
  └─ Emit: ExitsRequested

Oracle → setConsensusLayerData(report)
  ├─ ... existing flow ...
  ├─ partialExitDelta = report.validatorsPartiallyExitedBalance - last.validatorsPartiallyExitedBalance
  ├─ PendingPartialExitBalance -= min(partialExitDelta, PendingPartialExitBalance)
  ├─ ... _pullCLFunds routes exited funds to BalanceToRedeem ...
  └─ Modified preExitingBalance:
      preExiting = (requestedFullExits - stopped) * 32 ETH + PendingPartialExitBalance
```

### Keeper strategy (off-chain)

```
1. shortfall = redeemDemandInEth - (BalanceToRedeem + exitingBalance + preExitingBalance)
2. if shortfall <= 0: DONE
3. Sort validators by excess balance (excess = balance - 32 ETH) descending
4. Fill shortfall with partial exits (skip if EIP-7002 fee > threshold)
5. If shortfall remains: add full exits for ceil(remaining / 32 ETH)
6. Call River.requestExits({partialExits, fullExits})
```

---

## V3: Insolvency Protection

**Parts:** A8

**Depends on:** V1 (consolidation must be in place)

**Demo:** Consolidation executed → times out / oracle reports failure → buffer written down → `_assetBalance()` drops → CoverageFund donation → oracle pulls → conversion rate recovers.

### Contracts touched

| Contract | What changes |
|----------|-------------|
| **River.1.sol** | New `writeDownFailedConsolidation(requestId)` (admin/oracle callable). Configurable `MAX_CONSOLIDATION_DURATION`, `maxSingleConsolidationAmount`, `maxTotalPendingConsolidation` caps. Cap enforcement in `executeConsolidation()`. |
| **IOracleManager.1.sol** | `ConsensusLayerReport` extended with `failedConsolidationIds[]` |
| **OracleManager.1.sol** | Process `failedConsolidationIds` in `setConsensusLayerData` → call writedown for each |

### Non-UI Affordances

| Affordance | Type | Wires Out |
|------------|------|-----------|
| `writeDownFailedConsolidation(requestId)` | External fn (admin/oracle) | → `PendingConsolidationBalance -= failedAmount` → request.status = FAILED → emit |
| `MAX_CONSOLIDATION_DURATION` | Admin-configurable | Timeout for pending consolidations |
| `maxSingleConsolidationAmount` | Admin-configurable | Cap per consolidation in `executeConsolidation()` |
| `maxTotalPendingConsolidation` | Admin-configurable | Cap on total `PendingConsolidationBalance` in `executeConsolidation()` |
| `failedConsolidationIds` | Oracle report field | Per-report array of failed request IDs |

### Key flow

```
Detection Path A — Oracle:
  Oracle → setConsensusLayerData(report with failedConsolidationIds)
    └─ For each failedId:
        ├─ failedAmount = request.expectedBalance - request.reconciledBalance
        ├─ PendingConsolidationBalance -= failedAmount
        ├─ request.status = FAILED
        └─ Emit: ConsolidationFailed

Detection Path B — Timeout:
  Admin → writeDownFailedConsolidation(requestId)
    ├─ Require: request.status == PENDING
    ├─ Require: block.timestamp > request.requestTimestamp + MAX_CONSOLIDATION_DURATION
    ├─ PendingConsolidationBalance -= failedAmount
    ├─ request.status = FAILED
    └─ Emit: ConsolidationFailed

Recovery:
  Treasury/Insurance → CoverageFund.donate{value: failedAmount}()
  Next oracle reports → _pullCoverageFunds() → BalanceToDeposit ↑ → _assetBalance() recovers
```

---

## V0: ETH-Based Accounting Foundation

**Parts:** A9

**Depends on:** Nothing (foundation for all other slices)

**Demo:** `_assetBalance()` uses `InFlightDepositBalance` instead of `(depositedCount - clCount) * 32`. Exit demand tracks ETH amounts, not validator counts.

### Contracts touched

| Contract | What changes |
|----------|-------------|
| **River.1.sol** | `_assetBalance()` uses `InFlightDepositBalance` instead of count-based calc. Exit demand uses `PendingFullExitBalance + PendingPartialExitBalance` for `preExitingBalance`. Calls `demandExitBalance(ethAmount)` instead of `demandValidatorExits(count)`. |
| **ConsensusLayerDepositManager.1.sol** | `_depositValidator()` increments `InFlightDepositBalance += DEPOSIT_SIZE` |
| **OracleManager.1.sol** | Decrements `InFlightDepositBalance` when new validators activated. Reconciles `PendingFullExitBalance` from exited balance delta. |
| **OperatorsRegistry.1.sol** | New `demandExitBalance(ethAmount)` replaces `demandValidatorExits(count)`. New `CurrentExitDemandBalance` replaces `CurrentValidatorExitsDemand`. `requestValidatorExits()` updated to track ETH amounts via `FullExitRequest{pubkey, expectedBalance}`. |
| **State (new)** | `InFlightDepositBalance.sol`, `PendingFullExitBalance.sol`, `CurrentExitDemandBalance.sol` |

### Key changes

```
_assetBalance():
  OLD: validatorsBalance + deposits + committed + redeem + (depositedCount - clCount) * 32
  NEW: validatorsBalance + deposits + committed + redeem + InFlightDepositBalance

preExitingBalance:
  OLD: (requestedExits - stopped) * 32
  NEW: PendingFullExitBalance + PendingPartialExitBalance

Exit demand:
  OLD: demandValidatorExits(ceil(shortfall / 32))
  NEW: demandExitBalance(shortfall)
```

### Migration (initRiverV1_3)

```
InFlightDepositBalance = (DepositedValidatorCount - lastReport.validatorsCount) * 32 ether
CurrentExitDemandBalance = CurrentValidatorExitsDemand * 32 ether
PendingFullExitBalance = 0
```

See [spike-eth-based-accounting.md](spike-eth-based-accounting.md) for full details.

---

## Implementation Order

```
V0 (ETH Accounting) ──→ V1 (Consolidation) ──→ V3 (Protection)
                    ──→ V2 (Partial Exits)
```

**Recommended order:** V0 → V1 + V2 (parallel) → V3

- **V0 first:** Foundation — removes 32 ETH / count dependencies. All other slices build on this.
- **V1 next:** Highest value — enables institutional validator onboarding.
- **V2 in parallel with V1:** Independent of V1, uses V0's ETH-based exit demand.
- **V3 last:** Depends on V1. Adds recovery backstop.

---

## Slice Plans

- [V0-plan.md](V0-plan.md) — ETH-based accounting foundation: 12 implementation steps, ~9 files touched
- [V1-plan.md](V1-plan.md) — Validator Consolidation: 10 implementation steps, ~9 files touched
- [V2-plan.md](V2-plan.md) — Partial Exits via EIP-7002: 10 implementation steps, ~7 files touched
- [V3-plan.md](V3-plan.md) — Insolvency Protection: 9 implementation steps, ~7 files touched
