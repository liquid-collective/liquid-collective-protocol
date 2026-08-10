# Certora specs — current state

**The CI matrix does not compile.** Every conf in `confs_for_CI/` except `AllowlistV1.conf` fails at
the solc stage, so `.github/workflows/Certora.yaml` has not been verifying anything for those
contracts. This is pre-existing breakage: the last commit touching `certora/` is `a3bb3883`
(2026-06-04), which predates both the `LibOracleReporting` extraction and the OperatorsRegistry V3
refactor. Because `certoraRun` fails on compilation rather than on a rule, the breakage does not
look like a verification failure and has gone unnoticed.

Do not cite formal verification as coverage for anything below until this is repaired.

Reproduce:

```bash
FOUNDRY_SRC=certora/harness forge build --contracts certora/harness
```

## Two independent repairs

These are separate jobs in separate domains. They do not need to be done together.

### 1. `RiverV1Harness` — coupled to the pre-extraction architecture

`harness/RiverV1Harness.sol` mirrors the whole of the former
`OracleManagerV1.setConsensusLayerData` body, split into `helper1_`…`helper11_` so the specs can
step through a report. That body now lives in `contracts/src/libraries/LibOracleReporting.sol` and
is reached by DELEGATECALL, with every handler `private` to the library.

| Harness site | Breakage |
|---|---|
| `RiverV1Harness.sol:28`, `:268` | `_reportWithdrawToRedeemManager()` — now `private`, `LibOracleReporting.sol:526` |
| `RiverV1Harness.sol:37`, `:104`, and the `helper3`–`helper11` signatures | `ConsensusLayerDataReportingVariables` — now `LibOracleReporting.sol:54` |
| `RiverV1Harness.sol:160` | `_pullCLFunds` — now `private`, `LibOracleReporting.sol:364` |
| `RiverV1Harness.sol:257` | `_requestExitsBasedOnRedeemDemandAfterRebalancings` — now `private`, `LibOracleReporting.sol:463` |
| `RiverV1Harness.sol:274` | `_skimExcessBalanceToRedeem` — now `private`, `LibOracleReporting.sol:566` |
| `RiverV1Harness.sol:280` | `_commitBalanceToDeposit(vars.timeElapsedSinceLastReport)` — production now takes **two** args, `_commitBalanceToDeposit(uint256 _period, bool _slashingContainmentModeEnabled)`, `LibOracleReporting.sol:579` |

The last row matters most: the harness has drifted behind production *behaviourally*, not just in
types. Slashing containment was added to the commit path and the harness never learned about it, so
even a mechanical type fix would verify a report path that no longer matches the deployed one.

`specs_for_CI/River_base.spec:3-14` also names `OracleManagerV1.ConsensusLayerDataReportingVariables`
and the eleven helper selectors in `ignoredMethod`, so the specs move with the harness.

Affects `confs_for_CI/RiverV1.conf`, `SharesManagerV1.conf`, and `RedeemManagerV1.conf` (all three
list `harness/RiverV1Harness.sol` in `files`).

Options, cheapest first:

- Promote the `LibOracleReporting` handlers from `private` to `internal` and have the harness call
  them. River's own bytecode is unaffected (River only calls the `external`
  `setConsensusLayerData`), but internal library functions inline into the *harness*, so re-measure
  with `make size` before and after.
- Rebuild the harness around the single `external` entry point and drop the eleven-helper
  decomposition, accepting coarser rules.

### 2. `OperatorsRegistryV1Harness` — model changed, not just names

`harness/OperatorsRegistryV1Harness.sol:169`, `:188`, `:198-199` use
`IOperatorsRegistryV1.OperatorAllocation`, which no longer exists. The V3 refactor replaced
validator-count allocation with ETH-based allocation — see `ExitETHAllocation`,
`ELExitETHAllocation`, `ExitsViaConsolidationAllocation` and `OperatorFundingDelta` in
`contracts/src/interfaces/IOperatorRegistry.1.sol`. `totalAllocationValidatorCount` and
`pickNextValidatorsToDepositReturnCount` need re-deriving against the new model, not renaming.

Affects the six `OperatorRegistryV1_*.conf` files.

## What still works

`harness/RedeemManagerV1Harness.sol` compiles on its own — it only extends `RedeemManagerV1` and
exposes `_isMatch`, the queue/stack accessors and the `CLAIM_*` constants.
`specs_for_CI/RedeemManagerV1_for_CI.spec` has its River import commented out (line 1) and quantifies
only over `RedeemManagerV1Harness`, so `RedeemManagerV1.conf` lists `RiverV1Harness.sol` and
`OperatorsRegistryV1Harness.sol` purely as link targets for River's outbound calls. Repointing those
two entries at the production `contracts/src/River.1.sol:RiverV1` and
`contracts/src/OperatorsRegistry.1.sol:OperatorsRegistryV1` is very likely enough to bring the
redeem-path rules back, and verifies against production rather than a stale mirror. That change has
**not** been made here because it cannot be validated without `CERTORAKEY` and a Certora cloud run —
do it in the same change that runs the prover.

## Rules that a per-tranche redemption rate model would invalidate

Relevant if the redemption accounting changes. In `specs_for_CI/RedeemManagerV1_for_CI.spec`:

- `redeem_request_amount_non_increasing` — treats `amount == 0` as terminal.
- `full_claim_is_terminal_witness_nontrivial_antecedent` / `..._consequent` — built on the same
  `amount == 0` sentinel.
- `height_of_consequent_redeem_requests`, `first_redeem_request_height_is_zero` — depend on `amount`
  being the FIFO width.
- `claim_order__single_call__same_withdrawal_event__subsequent_redeem_requests[_no_invariant]` —
  assumes one rate per withdrawal event.

In `specs_for_CI/RiverV1_for_CI.spec:17-40`,
`riverBalanceIsSumOf_ToDeposit_Commmitted_ToRedeem_for_setConsensusLayerData` mirrors
`River.1.sol:452-456`, so it changes if anything is carved out of `_assetBalance()`.
