# Foundry Native Invariant Tests for Accounting Changes

**Date:** 2026-03-31
**Branch:** `feat/pectra/accounting-changes-test`
**Status:** Implemented

## Context

The protocol recently migrated from validator-count-based to ETH-amount-based accounting (Pectra upgrade). The existing test suite at `contracts/test/accounting/` has a custom step-function simulator with 6 invariants (I1-I6), but does **not** use Foundry's native stateful invariant testing (`invariant_` prefix, handler contracts, `targetContract()`).

This plan adds Foundry-native invariant tests that leverage the existing harness to get continuous property checking via Foundry's random call-sequence fuzzer.

## Files Created

```
contracts/test/accounting/invariant/
  AccountingHandler.sol           -- Handler contract (Foundry fuzzer target)
  AccountingInvariantTest.t.sol   -- invariant_ test contract
```

## Files Modified

```
foundry.toml  -- Added [invariant] section
```

## Existing Files Reused

- `AccountingHarnessBase.sol` — protocol stack deployment, helpers
- `BeaconChainSimulator.sol` — sim_* step functions, SimValidator state
- `AccountingInvariants.sol` — I1-I6 assertion logic, snapshot helpers

---

## Architecture

```
AccountingInvariantTest (is AccountingInvariants)
  ├── setUp(): deploys protocol via super.setUp(), creates handler, targetContract(handler)
  ├── handler_*() external wrappers: delegate to sim_*() internal functions
  ├── handler_*Count() view readers: expose sim state for handler preconditions
  └── invariant_*() functions: Foundry checks these after every handler call

AccountingHandler (standalone)
  ├── Constructor: takes AccountingInvariantTest reference
  ├── Bounded public functions: deposit(), activate(), advanceEpoch(),
  │   requestExit(), completeExit(), slash(), oracleReport()
  ├── Ghost variables: independent state tracking for cross-checks
  └── Precondition guards: early return (no revert) when action is invalid
```

The handler holds a reference to the test contract and calls its `handler_*()` external wrappers, which in turn call the `internal` sim_* functions. This preserves `vm.prank`/`vm.deal` cheatcode context.

---

## 1. AccountingHandler.sol

### Interface to test contract

```solidity
interface IAccountingActions {
    function handler_deposit(uint256 opIdx, uint256 n) external;
    function handler_activateValidators(uint256 n) external;
    function handler_advanceEpoch(uint256 rewardsPerValidator) external;
    function handler_requestExit(uint256 opIdx, uint256 ethAmount) external;
    function handler_completeExit(uint256 opIdx, uint256 ethAmount, uint256 penalty) external;
    function handler_slash(uint256 opIdx, uint256 penalty) external;
    function handler_oracleReport(bool rebalance, bool slashingContainment) external;
    function handler_pendingCount() external view returns (uint256);
    function handler_activeCount(uint256 opIdx) external view returns (uint256);
    function handler_exitingCount(uint256 opIdx) external view returns (uint256);
    function handler_operatorIndex(uint256 which) external view returns (uint256);
}
```

### Handler functions with bounding

| Function | Input Bounds | Precondition Guard |
|----------|-------------|-------------------|
| `deposit(opSeed, nSeed)` | opIdx = opSeed % 2, n = bound(nSeed, 1, 4) | None (sim_deposit auto-funds) |
| `activateValidators(nSeed)` | n = bound(nSeed, 1, pendingCount) | if pendingCount == 0: return |
| `advanceEpoch(rewardSeed)` | reward = bound(rewardSeed, 0, 0.008 ether) | None (no-op if no active) |
| `requestExit(opSeed, nSeed)` | opIdx % 2, n = bound(1, activeCount), eth = n * 32e18 | if activeCount == 0: return |
| `completeExit(opSeed, nSeed, penSeed)` | opIdx % 2, n = bound(1, exitingCount), penalty = bound(0, 2 ether) | if exitingCount == 0: return |
| `slash(opSeed, penSeed)` | opIdx % 2, penalty = bound(0.01 ether, 16 ether) | if activeCount == 0: return; sets ghost_slashOccurred |
| `oracleReport(modeSeed)` | rebalance = (modeSeed % 4 == 0), slashingContainment = ghost_slashOccurred | if no deposits ever made: return |

### Ghost variables

```solidity
uint256 public ghost_depositCount;   // total validators deposited
uint256 public ghost_reportCount;    // total oracle reports submitted
bool    public ghost_slashOccurred;  // true if slash happened since last report
```

### Call counters (debugging)

```solidity
uint256 public calls_deposit;
uint256 public calls_activate;
uint256 public calls_advanceEpoch;
uint256 public calls_requestExit;
uint256 public calls_completeExit;
uint256 public calls_slash;
uint256 public calls_oracleReport;
```

---

## 2. AccountingInvariantTest.t.sol

### setUp()

```solidity
function setUp() public override {
    super.setUp();  // deploys full protocol stack
    handler = new AccountingHandler(IAccountingActions(address(this)));
    targetContract(address(handler));
}
```

### External wrappers

Each wraps a `sim_*` call. The `handler_slash` and `handler_oracleReport` wrappers handle `_setAllowSharePriceDecrease` toggling:

- `handler_slash()` → `_setAllowSharePriceDecrease(true)` then `sim_slash()`
- `handler_oracleReport(rebalance, slashingContainment)` → if slashingContainment, sets allow decrease; calls `sim_oracleReport()`; resets to false

### State readers

Expose `_simValidators` state for handler precondition checks:
- `handler_pendingCount()` — count of Pending validators
- `handler_activeCount(opIdx)` — count of Active validators for operator
- `handler_exitingCount(opIdx)` — count of Exiting validators for operator
- `handler_operatorIndex(which)` — maps 0/1 to operatorOneIndex/operatorTwoIndex

---

## 3. Invariants

### Existing (I2, I3, I5, I6) — adapted for continuous checking

These are checked after **every** handler call (not just after oracle reports):

| Invariant | Property |
|-----------|----------|
| I2: ETH conservation | `totalUnderlyingSupply() <= _simTotalUserDeposited + _simCumulativeSkimmed` (upper-bound, non-tautological) |
| I3: InFlightDeposit consistency | `river.getInFlightDeposit() == _simInFlightDeposit` — checked **pre-report** in `_snapshotPreReport()` |
| I5: TotalDepositedETH monotonic | `getTotalDepositedETH() >= sum of all sim validator depositedETH` |
| I6: ExitedETH aggregate | sum of per-operator exited == total exited |

Note: I1 (share price) and I4 (per-operator tracking) are checked internally by `_assertAllInvariants()` during each `sim_oracleReport()` call, so they are tested indirectly.

### New Invariants (I7-I12)

**I7: Asset balance decomposition** — validates `_assetBalance()`
```
totalUnderlyingSupply() >= CommittedBalance + BalanceToDeposit + BalanceToRedeem + InFlightDeposit
```
The difference is `storedReport.validatorsBalance` which must be >= 0. A negative implied validators balance means accounting corruption.

**I8: TotalDepositedETH == sum of per-operator funded**
```
river.getTotalDepositedETH() == Σ operator[i].funded
```
Verifies the new aggregate field stays consistent with per-operator tracking. Any discrepancy = double-count or missed increment.

**I9: InFlightDeposit bounded by TotalDepositedETH**
```
river.getInFlightDeposit() <= river.getTotalDepositedETH()
```
InFlightDeposit is a subset of deposited ETH — can never exceed total.

**I10: EL solvency — River balance covers EL-held amounts**
```
address(river).balance >= BalanceToDeposit + CommittedBalance + BalanceToRedeem
```
The River contract must physically hold enough ETH to cover its tracked EL balances.

**I11: Shares-underlying bidirectional consistency**
```
if totalSupply > 0 then totalUnderlyingSupply > 0
if totalUnderlyingSupply > 0 then totalSupply > 0
```
Zero shares with nonzero underlying (or vice versa) = catastrophic accounting bug.

**I12: Cumulative exited ETH bounded by TotalDepositedETH**
```
totalExitedETH <= river.getTotalDepositedETH()
```
Cannot exit more than was ever deposited.

### Invariants I15-I20 (oracle report monotonicity & cross-checks)

These use ghost variables snapshotted after each `handler_oracleReport()` call to track monotonicity.

**I15: validatorsSkimmedBalance non-decreasing**
```
storedReport.validatorsSkimmedBalance >= ghost_lastSkimmedBalance
```
Cumulative skimmed rewards accumulator. Oracle rejects decreasing values.

**I16: validatorsExitedBalance non-decreasing**
```
storedReport.validatorsExitedBalance >= ghost_lastExitedBalance
```
Cumulative exited balance accumulator. Oracle rejects decreasing values.

**I17: Per-operator exitedETH non-decreasing**
```
exitedETHPerOperator[i] >= ghost_lastExitedPerOp[i]  for all i
```
The `reportExitedETH()` function explicitly enforces per-operator monotonicity.

**I18: Exit requests bounded by funded (continuous)**
```
for each operator: requestedExits <= funded AND exited <= funded
```
Extends I4 to continuous checking (not just after reports). Matches the documented struct invariant in `Operators.3.sol`.

**I19: CLValidatorCount bounded by total sim validators**
```
river.getLastConsensusLayerReport().validatorsCount <= _simValidators.length
```
On-chain activated validator count (from the stored oracle report) should never exceed total validators ever created by the simulator.

**I20: TotalDepositedETH exact match with sim**
```
river.getTotalDepositedETH() == Σ _simValidators[i].depositedETH
```
Strengthens I5 from `>=` to exact equality. No phantom increments.

---

## 4. foundry.toml configuration

```toml
[invariant]
runs = 128
depth = 32
fail_on_revert = false
```

`fail_on_revert = false` is critical because handler functions use early `return` for invalid preconditions, and `sim_oracleReport` may revert internally when a slash causes share price decrease without slashingContainment mode.

---

## 5. Running the tests

```bash
# Run all invariant tests
forge test --match-path "contracts/test/accounting/invariant/*" -vvv

# Run a specific invariant
forge test --match-test "invariant_I8" -vvv

# Run with deeper exploration
forge test --match-path "contracts/test/accounting/invariant/*" -vvv \
  --invariant-runs 256 --invariant-depth 64
```

## 6. Results

All 16 invariant functions pass across 128 runs x 32 depth = 4096 random handler calls each:

```
[PASS] invariant_I2_ethConservation()              (runs: 128, calls: 4096)
[PASS] invariant_I3_inFlightConsistency()          (runs: 128, calls: 4096)
[PASS] invariant_I5_totalDepositedETHMonotonic()   (runs: 128, calls: 4096)
[PASS] invariant_I6_exitedETHAggregate()           (runs: 128, calls: 4096)
[PASS] invariant_I7_assetBalanceDecomposition()    (runs: 128, calls: 4096)
[PASS] invariant_I8_totalDepositedETHConsistency() (runs: 128, calls: 4096)
[PASS] invariant_I9_inFlightBoundedByDeposited()   (runs: 128, calls: 4096)
[PASS] invariant_I10_elSolvency()                  (runs: 128, calls: 4096)
[PASS] invariant_I11_sharesUnderlyingConsistency() (runs: 128, calls: 4096)
[PASS] invariant_I12_exitedBoundedByDeposited()    (runs: 128, calls: 4096)
[PASS] invariant_I15_skimmedBalanceNonDecreasing() (runs: 128, calls: 4096)
[PASS] invariant_I16_exitedBalanceNonDecreasing()  (runs: 128, calls: 4096)
[PASS] invariant_I17_perOperatorExitedNonDecreasing()(runs: 128, calls: 4096)
[PASS] invariant_I18_exitRequestsBounded()         (runs: 128, calls: 4096)
[PASS] invariant_I19_clValidatorCountBounded()     (runs: 128, calls: 4096)
[PASS] invariant_I20_totalDepositedETHExactMatch() (runs: 128, calls: 4096)
```

Note: I13 (CommittedBalance alignment to 32 ETH) and I14 (validatorsCount non-decreasing) were evaluated but removed from the final suite.
