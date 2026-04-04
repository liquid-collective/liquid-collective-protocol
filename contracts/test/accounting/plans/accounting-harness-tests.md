# Accounting Test Harness — Test Catalogue

**Branch:** `feat/pectra/accounting-changes`
**Location:** `contracts/test/accounting/`

This document describes every test in the accounting harness, organized by suite. All tests drive the real on-chain contracts (River, Oracle, OperatorsRegistry) through a `BeaconChainSimulator` and assert 6 accounting invariants after every oracle report.

---

## Infrastructure

### `AccountingHarnessBase.sol`

Shared base for all scenario tests. Deploys the full protocol stack (River, Oracle, OperatorsRegistry, ELFeeRecipient, CoverageFund, Allowlist, DepositContractMock), runs the V1_3/V1_2 migration chain, and registers two operators (`operatorOneIndex`, `operatorTwoIndex`).

### `BeaconChainSimulator.sol`

Abstract contract that maintains an in-memory beacon chain state (`SimValidator[]`, cumulative rewards, epoch counter) and exposes named step functions used by all tests:

| Step function | What it does |
|---|---|
| `sim_deposit(opIdx, n)` | Funds River, calls `depositToConsensusLayerWithDepositRoot`, marks `n` validators **Pending** |
| `sim_activateValidators(n)` | Transitions `n` Pending → **Active** |
| `sim_advanceEpoch(rewardWei)` | Accrues `rewardWei` per Active validator as skimmed consensus rewards |
| `sim_requestExit(opIdx, ethAmount)` | Marks matching Active validators as **Exiting** |
| `sim_completeExit(opIdx, ethAmount, penalty)` | Marks Exiting validators as **Exited**; `exitedETH = currentBalance − penalty` |
| `sim_slash(opIdx, penalty)` | Reduces `currentBalance` of the first Active validator for the operator |
| `sim_oracleReport(rebalance?, slashingContainment?)` | Builds `ConsensusLayerReport` from sim state, warps time, funds Withdraw contract, submits through Oracle, asserts all invariants |

### `AccountingInvariants.sol`

Abstract mixin that defines the 6 invariants checked after every `sim_oracleReport`:

| ID | Invariant | What it checks |
|---|---|---|
| I1 | Share price non-decrease | `totalUnderlying / totalShares` does not decrease (skipped when `_allowSharePriceDecrease` is set) |
| I2 | ETH conservation | `totalUnderlyingSupply() ≤ _simTotalUserDeposited + _simCumulativeSkimmed` (upper bound on protocol-tracked ETH) |
| I3 | InFlightDeposit consistency | `river.getInFlightDeposit() == _simInFlightDeposit` — checked **before** the oracle report to avoid the report overwriting the value |
| I4 | Per-operator ETH conservation | For each operator: `fundedETH == Σ depositedETH`, `exitedETH == Σ exitedETH`, `requestedExits ≤ funded` |
| I5 | TotalDepositedETH monotonicity | `TotalDepositedETH` never decreases across reports |
| I6 | exitedETH aggregate | `exitedETHPerOperator[0] (total) == Σ exitedETHPerOperator[i>0]` |

---

## Scenario Tests

### `HappyPath.t.sol` (3 tests)

Normal lifecycle: deposit → activate → report cycles with reward accrual.

---

#### `testDepositActivateReport`

**What it tests:** The baseline deposit-activate-report cycle for a single operator.

1. Funds River with 3 × 32 ETH and deposits 3 validators for operator one.
2. Asserts `InFlightDeposit == 96 ETH` immediately after deposit.
3. Activates all 3 validators on the simulated beacon chain.
4. Submits an oracle report.
5. Asserts `InFlightDeposit == 0` (pending ETH cleared once oracle confirms activation).
6. All 6 invariants are checked by `sim_oracleReport`.

---

#### `testMultiOperatorWithRewards`

**What it tests:** Two operators with staggered deposit sizes accumulating rewards over multiple epochs.

1. Funds River with 10 × 32 ETH; deposits 6 validators to operator one and 4 to operator two.
2. Activates all 10 validators and submits a baseline oracle report.
3. Advances the epoch with `0.008 ETH` reward per validator and reports; repeats once more (2 reward cycles total).
4. Asserts `totalUnderlyingSupply > 10 × 32 ETH` — confirming rewards were incorporated.
5. Invariants checked after each of the 3 oracle reports.

---

#### `testIncrementalDeposits`

**What it tests:** Multiple deposit batches from the same operator between reports.

1. Deposits 2 validators in a first batch; asserts `InFlightDeposit == 64 ETH`.
2. Deposits 3 more validators in a second batch; asserts `InFlightDeposit == 160 ETH` (cumulative).
3. Activates all 5 and submits a report; asserts `InFlightDeposit == 0`.

---

### `InFlightETH.t.sol` (4 tests)

Edge cases around the `InFlightDeposit` tracker — validators deposited to the beacon chain but not yet oracle-confirmed.

---

#### `testReportWithPendingValidators`

**What it tests:** An oracle report submitted before validators are activated keeps `InFlightDeposit` intact.

1. Deposits 3 validators (all Pending).
2. Submits oracle report **without** activating validators first.
3. Asserts `InFlightDeposit == 96 ETH` — the oracle preserves the in-flight value when activation hasn't been confirmed.

---

#### `testPartialActivation`

**What it tests:** Partial activation progressively reduces `InFlightDeposit` across two reports.

1. Deposits 3 validators; activates only 2.
2. First oracle report: asserts `InFlightDeposit == 32 ETH` (1 still pending).
3. Activates the remaining 1; second oracle report.
4. Asserts `InFlightDeposit == 0`.

---

#### `testIncrementalDepositsBetweenReports`

**What it tests:** Deposits made after an initial cleared report correctly re-populate `InFlightDeposit`.

1. Deposits and activates 2 validators; reports → `InFlightDeposit == 0`.
2. Deposits 3 more validators; asserts `InFlightDeposit == 3 × 32 ETH`.
3. Activates the 3 new validators; reports → `InFlightDeposit == 0`.

---

#### `testReportInFlightETHIncreaseReverts`

**What it tests:** The protocol rejects a report that tries to *increase* `InFlightDeposit` when it should be zero.

1. Deposits 2 validators, activates them, reports → `InFlightDeposit == 0`.
2. Manually crafts a `ConsensusLayerReport` with `inFlightETH = 1 ETH` (an invalid upward change).
3. Submits the bad report via `oracle.reportConsensusLayerData` and asserts it reverts.

---

### `ExitAccounting.t.sol` (4 tests)

Per-operator `fundedETH` and `exitedETH` correctness across various exit scenarios.

---

#### `testCleanExit`

**What it tests:** A full clean exit (no penalty) correctly updates per-operator `fundedETH` and `exitedETH`.

1. Deposits and activates 4 validators for operator one; reports.
2. Requests exit of 2 validators, then marks them exited with zero penalty.
3. Reports and checks:
   - `operator.funded == 4 × 32 ETH` (unchanged — TotalDepositedETH never decreases).
   - `exitedETHPerOperator[operatorOneIndex] == 2 × 32 ETH`.

---

#### `testTwoOperatorExits`

**What it tests:** Independent exits from two operators are tracked separately and the aggregate total is consistent.

1. Deposits 3 validators each to operators one and two; activates all 6; reports.
2. Exits 1 validator from operator one, 2 from operator two (zero penalties).
3. Reports and checks per-operator `exitedETH` and the aggregate `totalExited == 3 × 32 ETH`.

---

#### `testSlashedExit`

**What it tests:** An exit with a slash penalty produces the correct reduced `exitedETH`.

1. Deposits 2 validators for operator one; activates; reports.
2. Requests exit of 1 validator, completes it with `1 ETH` penalty.
3. Sets `_allowSharePriceDecrease` (I1 skipped) and reports.
4. Asserts `exitedETHPerOperator[operatorOneIndex] == 32 ETH − 1 ETH`.

---

#### `testTotalDepositedETHMonotonic`

**What it tests:** `TotalDepositedETH` never decreases, even after validators fully exit.

1. Deposits 3 validators; records `totalDepositedETH`.
2. Activates and reports (asserts value unchanged).
3. Requests and completes exit of all 3 validators; reports again.
4. Asserts `TotalDepositedETH` still equals the value captured after deposit.

---

### `SlashingContainment.t.sol` (3 tests)

Slashing containment mode: the protocol pauses new exit requests when a large slash is detected.

---

#### `testSlashingContainmentModeActive`

**What it tests:** A slash reduces `totalUnderlyingSupply` and containment mode is reflected in the oracle report.

1. Deposits and activates 4 validators; reports.
2. Applies a `4 ETH` penalty via `sim_slash`.
3. Submits report with `slashingContainment = true`; allows share price decrease.
4. Asserts `totalUnderlyingSupply < 4 × 32 ETH` — the slash is fully reflected on-chain.

---

#### `testNoExitRequestsDuringContainment`

**What it tests:** While slashing containment is active the protocol issues zero new exit requests.

1. Deposits 4 validators; activates; reports.
2. Captures current `totalETHExitsRequested`.
3. Applies a `4 ETH` slash; submits containment report.
4. Asserts `totalETHExitsRequested` is unchanged — confirming exit logic is suppressed during containment.

---

#### `testContainmentEndAndResume`

**What it tests:** After slashing containment ends the protocol resumes normal oracle report processing.

1. Deposits 4 validators; activates; reports.
2. Applies a `2 ETH` slash; submits containment report (allows share price decrease).
3. Submits a third normal report without containment — asserts all 6 invariants pass, confirming the protocol has recovered and continues operating correctly.

---

### `RebalancingMode.t.sol` (2 tests)

Rebalancing mode: the protocol shifts the deposit buffer toward the redeem queue when demand exceeds exiting balance.

---

#### `testRebalancingModePreservesConservation`

**What it tests:** Enabling rebalancing does not break ETH conservation.

1. Funds River with 6 × 32 ETH; deposits 3 validators to operator one; activates; reports normally.
2. Submits a second report with `rebalance = true`.
3. All 6 invariants are checked after both reports.

---

#### `testResumeAfterRebalancing`

**What it tests:** Normal operation resumes correctly after a rebalancing cycle.

1. Deposits and activates 4 validators; reports normally.
2. Submits a rebalancing report.
3. Submits a third normal report (no flags).
4. All 6 invariants pass across all three reports.

---

### `Migration.t.sol` (3 tests)

`OperatorsRegistryV1_2` migration: V2 validator-count storage is scaled to V3 ETH-amount storage (×32 ETH).

Uses a `MigrationOperatorsRegistry` subclass that exposes `sudoPushV2Operator` and `sudoSetStoppedValidators` to write legacy V2 storage directly before running the migration.

---

#### `testMigrationV2toV3`

**What it tests:** Two operators with known funded/stopped validator counts migrate to correct ETH-based V3 values.

V2 state set up:
- Operator Alpha: `funded = 3 validators`, `stopped = 1 validator`
- Operator Beta: `funded = 5 validators`, `stopped = 2 validators`

Runs `initOperatorsRegistryV1_1()` then `initOperatorsRegistryV1_2()` and asserts:
- `operator[0].funded == 3 × 32 ETH`, `operator[1].funded == 5 × 32 ETH`
- `exitedETHPerOperator[0] == 1 × 32 ETH`, `exitedETHPerOperator[1] == 2 × 32 ETH`
- Aggregate `totalExited == 3 × 32 ETH`

---

#### `testMigrationEmptyState`

**What it tests:** Running the migration with no V2 operators produces an empty V3 state without reverting.

Runs `initOperatorsRegistryV1_1()` and `initOperatorsRegistryV1_2()` on a fresh registry with no operators and asserts `getOperatorCount() == 0`.

---

#### `testMigrationSingleOperatorNoStops`

**What it tests:** A single operator with zero stopped validators migrates cleanly with `exitedETH == 0`.

V2 state: 1 operator, `funded = 4`, `stopped = 0`.

After migration:
- `operator[0].funded == 4 × 32 ETH`
- `exitedETHPerOperator[0] == 0`

---

## Fuzz Tests

### `AccountingFuzz.t.sol` (4 tests, 1500 runs each)

All fuzz tests reuse the same `BeaconChainSimulator` step functions and assert all 6 invariants after every oracle report. Bounded inputs prevent APR violations (`MAX_VALIDATORS = 8`, `MAX_REWARD = 0.008 ETH`).

---

#### `testFuzz_depositActivateReport(uint8 n1, uint8 n2)`

**What it tests:** Random deposit splits across two operators followed by full activation and a report.

- `n1 ∈ [1, 8]` validators for operator one, `n2 ∈ [1, 8]` for operator two.
- Deposits both, activates all `n1 + n2`, submits one oracle report.
- Covers the full range of two-operator deposit sizes in a single step.

---

#### `testFuzz_rewardsAccrual(uint8 n, uint64 rewardWei)`

**What it tests:** Random validator counts combined with random reward amounts per epoch.

- `n ∈ [1, 8]` validators, `rewardWei ∈ [0, 0.008 ETH]`.
- Deposits, activates, reports baseline; advances one epoch by `rewardWei`; reports again.
- Verifies reward accrual preserves all invariants across the full reward range.

---

#### `testFuzz_exitFlow(uint8 nDeposit, uint8 nExit)`

**What it tests:** Random partial or full exits from a single operator.

- `nDeposit ∈ [2, 8]`, `nExit ∈ [1, nDeposit]` (always a valid subset).
- Deposits and activates `nDeposit` validators; reports; exits `nExit` validators; reports again.
- Verifies per-operator `fundedETH`/`exitedETH` consistency for all valid (nDeposit, nExit) combinations.

---

#### `testFuzz_randomSequence(uint256 seed)`

**What it tests:** A randomly structured multi-step sequence driven from a single seed.

Derives a deterministic but varied action sequence from `seed` using recursive `keccak256` hashing:

1. Deposits `n1 ∈ [1, 4]` + `n2 ∈ [1, 4]` validators (two operators); activates; reports.
2. With 50% probability (based on seed parity): advances one epoch with a random reward; reports.
3. Exits `exitN ∈ [0, n1]` validators from operator one (if `exitN > 0`): requests, completes, reports.

All 6 invariants are asserted after each oracle report, covering combinations of deposits, rewards, and exits in a single fuzz pass.
