# Accounting Test Harness Design

**Date:** 2026-03-24
**Branch:** `feat/pectra/accounting-changes`
**Status:** Approved

## Context

The `feat/pectra/accounting-changes` branch replaces validator-count-based accounting with ETH-amount-based tracking across the protocol:

- `DepositedValidatorCount` → `TotalDepositedETH`
- `stoppedValidatorCounts` (uint32[]) → `exitedETH` (uint256[]) per operator
- New `InFlightDeposit` state: ETH deposited to beacon chain but not yet oracle-confirmed
- `ValidatorDeposit[]` struct replaces `OperatorAllocation[]` (pubkey/sig passed directly by keeper)
- `reportStoppedValidatorCounts` → `reportExitedETH`
- `OperatorsV3` (ETH-based) replaces `OperatorsV2` (validator-count-based)
- `fundedETH` and `incrementFundedETH` per operator
- `initRiverV1_3` and `initOperatorsRegistryV1_2` migrations

The off-chain actors are:
- **Keeper**: calls `depositToConsensusLayerWithDepositRoot(ValidatorDeposit[], depositRoot)`
- **Oracle members**: call `oracle.reportConsensusLayerData(ConsensusLayerReport)`

## Goal

Build a comprehensive Solidity/Foundry test harness in `contracts/test/accounting/` that:
1. Emulates beacon chain state transitions via step functions
2. Drives the real on-chain contracts (River, Oracle, OperatorsRegistry) through realistic scenarios
3. Asserts all accounting invariants after every state transition
4. Covers happy paths, ETH-accounting edge cases, adversarial/containment scenarios, and migration correctness
5. Provides a fuzz layer (Approach B) built on top of the same step functions

## Approach: Step-Function Simulator (Approach A + B)

A `BeaconChainSimulator` abstract contract models beacon chain state in-memory and exposes named step functions. Scenarios are written as linear scripts in concrete test contracts. A fuzz test drives random sequences of the same step functions.

## Folder Structure

```
contracts/test/accounting/
├── BeaconChainSimulator.sol       # abstract base — beacon state model + step functions
├── AccountingInvariants.sol       # abstract mixin — all invariant assertions
├── AccountingHarnessBase.sol      # abstract base — full protocol stack setup
├── scenarios/
│   ├── HappyPath.t.sol            # normal deposit → beacon deposit → epoch → report cycles
│   ├── InFlightETH.t.sol          # InFlightDeposit edge cases
│   ├── ExitAccounting.t.sol       # exitedETH per operator, fundedETH consistency
│   ├── SlashingContainment.t.sol  # slashing mode, partial slashes
│   ├── RebalancingMode.t.sol      # deposit-to-redeem rebalancing
│   └── Migration.t.sol            # V2 → V3 migration correctness
└── fuzz/
    └── AccountingFuzz.t.sol       # random action sequences over the same step functions
```

## BeaconChainSimulator — Beacon State Model

```solidity
enum ValidatorState { Pending, Active, Exiting, Exited }

struct SimValidator {
    uint256 operatorIndex;
    uint256 depositedETH;   // always 32 ether currently
    ValidatorState state;
    uint256 exitedETH;      // 32 ether minus slash penalty on exit
}

// State tracked as individual variables in BeaconChainSimulator (no struct in actual impl):
//   SimValidator[] _simValidators
//   uint256 _simCumulativeSkimmed        -- monotonically increasing cumulative skimmed rewards (0x01)
//   uint256 _simCumulativeAutocompounded -- monotonically increasing cumulative autocompounded rewards (0x02)
//   uint256 _simCumulativeExited         -- monotonically increasing cumulative exited ETH
//   uint256 _simInFlightDeposit          -- ETH sent to deposit contract, not yet oracle-confirmed
//   uint256 _simTotalDepositedActivatedETH -- cumulative ETH activated on the CL (incremented in sim_activateValidators)
//   uint256 _lastReportedSkimmed / _lastReportedExited / _lastReportEpoch
```

### Step Functions

| Function | Description |
|---|---|
| `sim_deposit(opIdx, n)` | Creates `n` `ValidatorDeposit` entries for `opIdx`, calls real `depositToConsensusLayerWithDepositRoot`, marks validators `Pending`, asserts `InFlightDeposit` increased |
| `sim_activateValidators(n)` | Transitions `n` pending → active; increments `_simTotalDepositedActivatedETH` by `n × 32 ETH`; reflected in next oracle report as a `totalDepositedActivatedETH` increase, which causes `InFlightDeposit` to decrease |
| `sim_advanceEpoch(rewardsPerValidator)` | Models 0x01 skimming: accrues rewards swept from CL to EL each epoch |
| `sim_autocompound(rewardsPerValidator)` | Models 0x02 autocompounding: rewards increase validator CL balances rather than being swept |
| `sim_requestExit(opIdx, ethAmount)` | Marks validators as exiting |
| `sim_completeExit(opIdx, ethAmount, penalty)` | Marks validators as exited; `exitedETH = depositedETH - penalty` |
| `sim_slash(opIdx, penalty)` | Applies balance penalty; optionally activates slashing containment in next report |
| `sim_oracleReport(flags?)` | Builds `ConsensusLayerReport` from `SimBeaconState`, submits through real Oracle, runs **all invariants** |

## AccountingInvariants — Invariant Assertions

All invariants are checked after every `sim_oracleReport` call (and after deposits for deposit-specific invariants).

**I1 — Share price non-decrease**
`totalUnderlying_after / totalShares >= totalUnderlying_before / totalShares`
(skipped in explicit slashing scenarios)

**I2 — ETH conservation**
`river.totalUnderlyingSupply() <= _simTotalUserDeposited + _simCumulativeSkimmed + _simCumulativeAutocompounded`
(upper bound check using externally tracked values, making it non-tautological; also asserts `> 0` when deposits have been made)

**I3 — InFlightDeposit consistency**
`river.getInFlightDeposit() == _simInFlightDeposit` — checked **before** each oracle report (in `_snapshotPreReport`) rather than after, because post-report the oracle itself sets `InFlightDeposit` making the check a tautology

**I4 — Per-operator ETH conservation**
For each operator `i`:
- `operator[i].fundedETH == Σ depositedETH for operator i`
- `operator[i].exitedETH <= operator[i].fundedETH`
- `operator[i].exitedETH == Σ exitedETH for operator i` (from SimBeaconState)

**I5 — TotalDepositedETH monotonicity**
`TotalDepositedETH` never decreases; equals sum of all `fundedETH` across operators

**I6 — exitedETHPerOperator aggregate**
`exitedETHPerOperator[0] == Σ exitedETHPerOperator[i>0]`

## Scenario Coverage

### HappyPath.t.sol
- Deposit 10 validators across 2 operators
- 3 epoch advances with reward accrual
- Oracle reports at each epoch
- Clean exits for all validators
- Assert all invariants at every step

### InFlightETH.t.sol
- Deposit 5 validators → oracle report before activation (inFlightETH still set)
- Activate validators → oracle report reduces inFlightETH
- Attempt to report `inFlightETH > current` (expect `InvalidInFlightETHIncrease` revert)
- Multiple deposits interleaved with partial activations

### ExitAccounting.t.sol
- 3 operators with exits at different rates
- Verify per-operator `fundedETH` and `exitedETH` at each step
- Attempt to report `exitedETH > fundedETH` for an operator (expect revert)
- Partial exits (less than full 32 ETH)

### SlashingContainment.t.sol
- Apply slash penalty → containment mode activates in oracle report
- Verify no new exit requests are emitted while containment is active
- Penalty drops below lower threshold → containment mode deactivates
- Assert share price decrease bounded by slash amount

### RebalancingMode.t.sol
- Build large redeem demand with low exiting balance
- Rebalancing mode flag set in oracle report
- Verify deposit buffer moves to redeem side
- Assert ETH conservation through the rebalancing

### Migration.t.sol
- Set up V2 state (operator validator counts, stoppedValidators)
- Run `initOperatorsRegistryV1_2` + `initRiverV1_3`
- Assert V3 state: `fundedETH == funded * 32 ether`, `exitedETH == stoppedValidators * 32 ether`
- Assert `TotalDepositedETH` and `InFlightDeposit` match expected values
- Run a full oracle report post-migration and assert all invariants

## Fuzz Layer (AccountingFuzz.t.sol)

A single `testFuzz_randomActionSequence(uint256 seed)` picks a random sequence of step functions with bounded-random parameters using `vm.assume` / `bound`. All invariants run after each step. The same `SimBeaconState` and step functions are reused — no duplication.

Action weights (approximate): deposit 25%, activateValidators 15%, advanceEpoch 20%, requestExit 15%, completeExit 15%, oracleReport 10%.

## Protocol Stack Setup (AccountingHarnessBase)

Mirrors `RiverV1TestBase` pattern: deploys River, Oracle, OperatorsRegistry, ELFeeRecipient, CoverageFund, Allowlist, DepositContractMock. Adds:
- `initRiverV1_3()` call after `initRiverV1_2()`
- `initOperatorsRegistryV1_2()` call after `initOperatorsRegistryV1_1()`
- Helper to register operators and whitelist test users
- `depositRoot` mock on `DepositContractMock` for keeper calls
