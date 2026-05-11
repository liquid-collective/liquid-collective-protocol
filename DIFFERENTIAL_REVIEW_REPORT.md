# Differential Security Review — bs-2754-on-pectra → main

**Date:** 2026-05-11
**Reviewer:** Claude (Opus 4.7)
**Branch:** `bs-2754-on-pectra`
**Base:** `main`
**Scope:** 59 files, ~16,000 lines, 56 commits

---

## Executive Summary

This is a substantial Pectra upgrade for the Liquid Collective protocol introducing four interacting subsystems:

1. **Deposit Security Attestation Committee** — quorum of ECDSA-signed attesters gating deposit submission, plus BLS deposit-message verification on-chain (`DepositToConsensusLayerValidation`, `BLS12_381` library).
2. **External `DepositDataBuffer`** — off-contract storage of pre-signed deposit batches; the buffer is removed from the trust chain by committing to `keccak256(abi.encode(deposits))`.
3. **ETH-based accounting (V3 operators)** — replaces validator-count accounting with wei-denominated `funded` / `requestedExits` / `activeCLETH` to support Pectra autocompounding (0x02 WC, 1–2048 ETH validators).
4. **Removal of validator-key on-chain storage** — `addValidators` / `removeValidators` / `pickNextValidatorsToDeposit` / `forceFundedValidatorKeysEventEmission` deleted; keys now arrive at deposit time from the buffer.

`Withdraw.1.sol` is also flipped from `0x01` to `0x02` withdrawal-credentials prefix, enabling autocompounding for all future validators.

Overall the design is sound, the trust model is well-thought-through (buffer is untrusted, attesters and oracle are trusted, deposit contract is canonical), and the new code is well-commented. The findings below are mostly **defense-in-depth / observability** concerns; one is a **latent invariant break** in the long term, and several rotted comments suggest a removed safeguard that should be reinstated or removed.

| Severity | Count |
|----------|-------|
| High     | 0     |
| Medium   | 2     |
| Low      | 4     |
| Info     | 5     |

**Confidence:** Medium-High for changed code; the BLS12-381 library is adapted from Lido and is not independently audited here — see `Coverage Limitations`.

---

## Risk-Classified Changes

| File | Risk | Notes |
|---|---|---|
| `components/DepositToConsensusLayerValidation.sol` | HIGH | New attestation+BLS verification surface |
| `components/ConsensusLayerDepositManager.1.sol` | HIGH | New deposit entry point; ETH transfer |
| `libraries/BLS12_381.sol` | HIGH | New cryptography library (adapted from Lido) |
| `River.1.sol` | HIGH | `initRiverV1_3` migration, in-flight ETH accounting |
| `OperatorsRegistry.1.sol` | HIGH | V2→V3 migration; exit/funding semantics flipped to wei |
| `components/OracleManager.1.sol` | MEDIUM | New `totalDepositedActivatedETH` invariant; in-flight reduction |
| `state/river/*` (8 new libs) | MEDIUM | New unstructured-storage slots |
| `state/operatorsRegistry/Operators.3.sol` | MEDIUM | New operator schema, exited-ETH array layout |
| `Withdraw.1.sol` | MEDIUM | `0x01` → `0x02` WC prefix flip |
| `interfaces/IDepositDataBuffer.sol` | LOW | Interface only |
| Tests / accounting harness / docs | LOW | Tests, fork migrations, plans |

---

## Findings

### M-1 — `ExitedETHExceedsPriorCLETH` declared but never raised; per-operator sanity bound on oracle-reported exits removed

**Files:**
- `contracts/src/interfaces/IOperatorRegistry.1.sol:149` (declaration)
- `contracts/src/OperatorsRegistry.1.sol` — `_setExitedETH` (the corresponding check is absent)
- `contracts/test/River.1.t.sol:1559,2440` — test comments reference a check that is not implemented

**Context:**
In `main`, `_setStoppedValidatorCounts` enforced per-operator `stoppedCount <= operator.funded` via `StoppedValidatorCountAboveFundedCount`. In the new code that check is removed from `_setExitedETH`. A successor error `ExitedETHExceedsPriorCLETH(operatorIndex, exitedETH, priorActiveCL)` is declared in the interface, and two test comments (`River.1.t.sol:1559`, `:2440`) explicitly say `// Populate activeCLETH … so ExitedETHExceedsPriorCLETH passes`, but **the check itself does not exist in production code**.

**Impact:**
- A buggy or malicious oracle can report `exitedETH[op] > activeCLETH[op]` (or even an arbitrarily large value), and the only on-chain sanity guard is the aggregate `totalExitedETH <= _totalDepositedETH` bound. Per-operator inflation is invisible.
- `_setExitedETH` already bumps `operator.requestedExits` up to match a high reported exit, so the next `incrementFundedETH` for that operator will revert (`OperatorIgnoredExitRequests`) until the oracle "catches up". An attacker controlling the oracle can therefore strand a specific operator without other operators noticing.
- The dangling error declaration and test comments referencing it are misleading and rot the codebase.

**Recommendation:**
Either (a) reinstate the per-operator check that the code obviously intended — e.g. require `_exitedETH[idx] <= operators[idx-1].funded` (allowing rewards) **or** `_exitedETH[idx] - currentExited[idx] <= operators[idx-1].activeCLETH` — and raise `ExitedETHExceedsPriorCLETH` from it; or (b) delete the error declaration and the stale test comments. Pick one — do not leave both half-states.

---

### M-2 — Long-term invariant: `totalExitedETH > totalDepositedETH` will eventually revert oracle reports on a healthy chain

**File:** `contracts/src/OperatorsRegistry.1.sol` — `_setExitedETH`

```solidity
if (vars.totalExitedETH > _totalDepositedETH) {
    revert ExitedETHExceedsDepositedETH();
}
```

**Reasoning:**
- `TotalDepositedETH` is monotone-increasing by *deposits only* (set in `ConsensusLayerDepositManager.depositToConsensusLayerWithAttestation`).
- `exitedETHPerOperator` per the interface comment includes *all* CL-side exit balance — i.e. principal plus accumulated rewards (and for 0x02 validators, autocompounded balance up to 2048 ETH).
- Once validators have been exiting long enough that cumulative rewards-on-exit exceed cumulative deposits since genesis, `totalExitedETH > _totalDepositedETH` becomes true and the oracle report reverts.
- At realistic APRs the timescale is years, but the protocol is upgrade-bounded indefinitely, so this is a real latent issue.

**Impact:** Eventual oracle-reporting outage requiring an upgrade. Low-probability in the short term, but worth either documenting or fixing now while the invariant is being re-derived.

**Recommendation:** Either bound against a value that grows with rewards (e.g. `totalDepositedETH + cumulativeRewardsToDate`) or remove the aggregate check entirely and rely on the (recommended in M-1) per-operator check + the existing oracle-report bounds (`annualAprUpperBound`). Document the chosen bound in the function NatSpec.

---

### L-1 — `_recover` non-canonical `v` normalization is unconventional; `tryRecover(v,r,s)` already handles signature malleability but accepting `v < 27` widens parser surface

**File:** `contracts/src/components/DepositToConsensusLayerValidation.sol:349–366`

```solidity
uint8 v = uint8(sig[64]);
if (v < 27) v += 27;
if (v != 27 && v != 28) return address(0);
```

`OpenZeppelin ECDSA.tryRecover(digest, v, r, s)` rejects `v ∉ {27, 28}` and high-s values. The pre-normalization step is functionally fine, but it deviates from the standard EIP-2098 form (which would split off the parity bit from `s`) and from OZ's own `tryRecover(bytes)` overload. Two callers writing slightly different signature formats can both be accepted by this contract but rejected by neighboring contracts — surprising behavior for off-chain tooling.

**Recommendation:** Prefer `ECDSA.tryRecover(digest, sig)` from OpenZeppelin and let the library normalize. Saves code and eliminates the assembly load.

---

### L-2 — `initRiverV1_3` silently deduplicates the `_attesters` array

**File:** `contracts/src/River.1.sol:187–194`

```solidity
for (uint256 i = 0; i < _attesters.length; i++) {
    if (_attesters[i] == address(0)) revert ...;
    if (!Attesters.isAttester(_attesters[i])) {
        Attesters.setAttester(_attesters[i], true);
        Attesters.setCount(Attesters.getCount() + 1);
        emit SetAttester(_attesters[i], true);
    }
}
```

If an admin passes `[A, B, A]`, the loop processes A, B, and skips the second A. The quorum is then checked against the actual count, so the post-condition is safe — but the admin's apparent intent ("I am registering 3 attesters") is silently discarded, and an emergency rotation script that re-sets the same attester would no-op without warning. The `setAttester` external function rejects no-ops with `AttesterStatusUnchanged` (added intentionally for exactly this reason — see commit `4daae0f`); the init path bypasses that safeguard.

**Recommendation:** Revert on duplicates in `_attesters`, matching the explicit-feedback policy of `setAttester`.

---

### L-3 — Domain separator caches `block.chainid` at init time with no rotation path

**File:** `contracts/src/state/river/DomainSeparator.sol`

The NatSpec acknowledges this: "In the extremely rare event of a chain fork where chainid changes, an admin-driven implementation upgrade that exposes a setter to recompute `DomainSeparator` could be added." The cache is reset only via re-init or an as-yet-unimplemented setter. Compared to recomputing on every call this saves gas, but if a chain split ever occurs an upgrade is required to resume deposit attestations on the surviving chain.

**Recommendation:** Either add an admin-only `recomputeDomainSeparator()` now, or document the upgrade-required dependency in `RELEASE.md` so operators know what to do.

---

### L-4 — `_updateFundedETHFromBuffer` does not bound `deposits.length` × `operatorCount` memory growth

**File:** `contracts/src/River.1.sol:_updateFundedETHFromBuffer`

The function allocates `buckets = highestOpIdx + 1` arrays. The per-deposit `opIdx >= operatorCount` revert caps `buckets` at `operatorCount`, but if a future admin grows `operatorCount` to thousands, a small batch targeting only `operator:operatorCount-1` allocates `operatorCount`-sized arrays in memory. Quadratic-ish blowup is unlikely at current scale (and bounded by gas) but the function does not need to allocate beyond `len`.

**Recommendation:** Optional. Build a compact `(opIdx → bucket)` map (sorted dedup of `opIndices`) and allocate `bucket.length`-sized arrays. Adapter then needs to expand to `operatorCount` at the registry call only if the registry truly requires positional indexing — `incrementFundedETH` does require this since it iterates by index, so leave as-is unless growth becomes a real concern, and just be aware.

---

### I-1 — No end-to-end test exercises a real BLS signature

**Files:**
- `contracts/test/components/ConsensusLayerDepositManagerAttestation.t.sol` mocks `verifyBLSDeposit` in 15 of 16 tests
- `contracts/test/libraries/BLS12_381_SSZ.t.sol` (4 tests) covers `computeDepositDomain` and `depositMessageSigningRoot` only; it does not call `verifyDepositMessage` on a real pubkey/signature pair

The BLS library is adapted from Lido (well-tested upstream) and Solady, which is a meaningful mitigation. Still, the integration glue in `DepositToConsensusLayerValidation._verifyBLSSignatures` (memory → calldata via `address(this).staticcall`) is non-trivial and is not exercised end-to-end on real deposit data anywhere in this repo.

**Recommendation:** Add a single test vector taken from an actual mainnet Pectra-style deposit (pubkey, signature, withdrawal-credentials, amount, depositY) and assert `verifyDepositMessage` returns. Also add a known-bad-sig vector that asserts `InvalidSignature`. This anchors the calldata layout against a real-world example.

---

### I-2 — Replay protection of attestation signatures relies on the deposit-contract root advancing; no nonce or expiry

**File:** `DepositToConsensusLayerValidation._verifyAttestationQuorum`

```solidity
bytes32 onChainRoot = _depositContract().get_deposit_root();
if (onChainRoot != depositRootHash) revert DepositRootMismatch(...);
```

This is effective replay protection in practice: each successful call advances the canonical deposit contract's Merkle root, so a previously-signed `(bufferId, depositRootHash)` tuple is no longer valid afterward. However:

- If a Pectra fork or future EIP ever introduces a way to "roll back" the deposit contract Merkle root (vanishingly unlikely on L1, but conceptually possible on a future L2 fork or test fork), the assumption breaks silently.
- Off-chain signing of attestations for a *future* `depositRootHash` (i.e. signers gather signatures, the keeper waits for a window before submitting) is possible. If signers sign for "the root I expect after batch X completes" rather than "the root I see now", they can be tricked into signing for a different in-flight batch. Mitigated because attesters sign `(bufferId, root)` and bufferId pins the exact deposits.

**Recommendation:** Document the deposit-root-advance replay model explicitly in NatSpec. Optional: add a per-batch nonce or expiry timestamp to the `Attest` typehash for belt-and-suspenders defense, though this complicates signer coordination.

---

### I-3 — `MAX_SIGNATURES = 20` and `MAX_ATTESTERS = 32` are decoupled

**File:** `DepositToConsensusLayerValidation.sol:114,117`

A quorum cannot exceed `MAX_SIGNATURES = 20` (enforced in `setAttestationQuorum`), but `MAX_ATTESTERS = 32`. If quorum is set near the cap (say 20) and 12+ attesters are unavailable, the system halts deposits. The decoupling is intentional — you want a buffer of standby attesters — but only 8 spare attesters above the quorum cap. The NatSpec for `MAX_SIGNATURES` says "Bounds the O(n²) duplicate-detection loop" which is the correct rationale; just worth verifying that operations can tolerate the gap between these constants.

**Recommendation:** None — informational. Consider documenting the operational reasoning in `audits/` or `RELEASE.md`.

---

### I-4 — Reentrancy is closed by access control, not by a guard

**File:** `ConsensusLayerDepositManager.depositToConsensusLayerWithAttestation`

State updates (`CommittedBalance`, `InFlightDeposit`, `TotalDepositedETH`) happen after external calls to `OperatorsRegistry.incrementFundedETH` and the canonical deposit contract. Both callees are trusted; only the keeper can invoke the entry point. So reentrancy is not currently exploitable. Adding `ReentrancyGuard` would be belt-and-suspenders. Not a finding, just an awareness item if the trust model ever loosens.

---

### I-5 — Comments referencing future-tense actions ("This is ok to set 0 here because it will be updated via the oracle report") encode trust assumptions

**File:** `contracts/src/OperatorsRegistry.1.sol:_migrateOperators_V2_3`

The migration sets each operator's `activeCLETH = 0`, expecting the next oracle report to populate it. Between migration completion and the first oracle report, `requestETHExits` would compute `available = 0` for every operator, blocking exits. If the oracle report is delayed (or paused), the system cannot honor redemptions. This is mostly an operational concern but worth ensuring the rollout playbook sequences "deploy V1_3 → oracle reports → enable keeper" in that exact order.

**Recommendation:** Document the migration sequencing requirement in `RELEASE.md` and/or the deploy script.

---

## Migration Risk

`initRiverV1_3` performs five distinct mutations atomically:

1. `initConsensusLayerDepositManagerV1_2` — overwrites `WithdrawalCredentials` (changes WC prefix from `0x01` to `0x02`).
2. `TotalDepositedETH = depositedValidatorCount * 32 ETH` — *assumes all previous deposits were exactly 32 ETH*. Correct for the 0x01 era but no on-chain assertion of this assumption.
3. `InFlightDeposit = (depositedValidatorCount - clValidatorCount) * 32 ETH` — same assumption.
4. New `lastConsensusLayerReport` constructed with `totalDepositedActivatedETH = (depositedValidatorCount * 32 ETH) - InFlightDeposit`.
5. Attesters, quorum, domain separator, deposit data buffer all populated.

`Operators V1_2.initOperatorsRegistryV1_2` (note: must be called separately on the registry):
- Migrates each operator from `OperatorsV2` to `OperatorsV3`, multiplying `funded` and `requestedExits` by `DEPOSIT_SIZE`.
- Migrates `stoppedValidators` array (uint32[]) to `exitedETH` array (uint256[]) by multiplying every entry by `DEPOSIT_SIZE`.
- Existing `OperatorsV2` storage is **not cleared** (marked deprecated). Total storage cost in this transaction is opCount × (V3 push + V2 read). For 50 operators this is fine; for very large opCount it could approach block-gas limits — confirm pre-deploy with a fork test.

**Both `River.initRiverV1_3` and `OperatorsRegistry.initOperatorsRegistryV1_2` must be invoked in the same upgrade transaction (or with no oracle reports in between) to avoid mid-migration state.** I recommend a dry-run on a mainnet fork with the actual mainnet operator count and `LastConsensusLayerReport` state.

---

## Coverage Limitations

- The BLS pairing implementation is adopted as-is from Lido; this review did **not** re-audit the BLS arithmetic, hash-to-curve, or subgroup checks. The upstream is well-vetted, and the wrapper integration (`_verifyBLSSignatures` calling `verifyBLSDeposit` via staticcall) is exercised in mock form by all attestation tests. See **I-1** for the corresponding test-coverage gap.
- The accounting harness, invariant tests, and migration fork tests under `contracts/test/accounting/` and `contracts/test/fork/mainnet/2.operatorsMigrationV2toV3.t.sol` were inventoried but not individually executed by this review. Counts: 16 attestation tests, 74 River tests, 64 OperatorsRegistry tests, 6 accounting scenario test files, and 2 new migration fork tests (V1→V3 and V2→V3) — meaningful coverage.
- The off-chain `DepositDataBuffer` contract is **not** in this diff. Its on-chain trust model is well-bounded by `BufferIdMismatch` rehashing in `validate()`, but its admin and writer semantics need to be reviewed in their own change.

---

## Recommendations Summary

| # | Action | Effort |
|---|---|---|
| M-1 | Decide: reinstate per-operator exited-ETH bound and use `ExitedETHExceedsPriorCLETH`, **or** delete the error + stale test comments | S |
| M-2 | Re-derive the `totalExitedETH` bound to allow for rewards-on-exit, or document the upgrade plan for when the bound trips | S |
| L-1 | Replace custom `_recover` with `ECDSA.tryRecover(digest, sig)` | XS |
| L-2 | Revert on duplicate addresses in `initRiverV1_3._attesters` | XS |
| L-3 | Add admin-only `recomputeDomainSeparator()` or document upgrade plan | S |
| L-4 | (Optional) compact bucket allocation in `_updateFundedETHFromBuffer` | M |
| I-1 | Add at least one end-to-end BLS test vector with real signature | S |
| I-2 | NatSpec the deposit-root-advance replay model | XS |
| I-5 | Document the migration sequencing in `RELEASE.md` | XS |

(XS = <30 min, S = 1–2 hr, M = ½ day)
