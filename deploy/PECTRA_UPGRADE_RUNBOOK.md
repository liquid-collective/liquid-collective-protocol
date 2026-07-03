# Pectra Upgrade Runbook — Atomic Reinitializer Requirement

## Why this document exists

Every protocol upgrade hook (`init*` / `initialize*` guarded by the `init(N)` modifier in
`contracts/src/Initializable.sol`) is a **public, version-gated, one-shot initializer with no
caller authorization**. The `init(N)` modifier only checks and increments the version counter — it
performs **no** admin / proxy-admin / caller check.

These initializers are safe **only** when the implementation swap and the initializer call happen
in a **single atomic transaction** via `upgradeToAndCall`. If an upgrade is ever performed as
`upgradeTo` (implementation swap only) followed by a **separate** initializer transaction, there is
a window in which the version counter matches but the initializer has not yet run. During that
window, on a transparent proxy, any non-admin call to the initializer selector is forwarded to the
new implementation (transparent-proxy fallback), the version gate still passes, and the caller sets
attacker-chosen parameters — permanently misconfiguring that version.

Concretely, a front-run in that window could set:

- `WithdrawV1.initWithdrawV1_1` → attacker-chosen Pectra withdrawal / consolidation contract
  addresses, operators-registry address, and attestation-verifier address.
- `OperatorsRegistryV1.initOperatorsRegistryV1_2` → attacker-chosen withdraw address, and it
  consumes the one-shot V2→V3 migration.
- `RiverV1.initRiverV1_3` → attacker-chosen consolidation coverage fund, attestation verifier,
  external-consolidation recipient mapping, and consolidator.

This risk is **operational**: it is fully closed by always upgrading atomically. This runbook makes
that requirement explicit and checkable.

> Why not enforce it on-chain with a caller guard? On the OZ 4.9.x transparent proxy,
> `upgradeToAndCall` reaches the initializer via an internal `delegatecall`, so inside a legitimate
> atomic init `msg.sender` is the **ERC1967 proxy admin** (the ProxyFirewall), not the
> `Administrable` protocol admin. A `onlyAdmin` (protocol-admin) guard would therefore revert every
> real upgrade, and the only guard that works (reading the ERC1967 admin slot) also breaks the
> direct-implementation test harnesses. The atomic-upgrade requirement enforced here is the
> accepted mitigation.

## The rule

**Every reinitializer MUST be executed atomically via
`proxy.upgradeToAndCall(newImplementation, abi.encodeCall(InitFn, args))` submitted by the proxy
admin. NEVER submit a bare `upgradeTo` followed by a separate initializer transaction, and never
submit a standalone initializer transaction.**

This is the pattern already used by the deploy tooling — see the reference implementation
`initializeProxyIfNeeded` in
`deploy/hoodi/03_deploy_river_oracle_operators_registry_and_redeem_manager.ts`, which calls
`proxy.upgradeToAndCall(implementation, initCalldata)`. The mainnet Pectra upgrade script MUST use
the same construction for every proxy it initializes.

## Reinitializers and expected pre-upgrade version counters

The `Initializable` version counter for each proxy lives at storage slot
`keccak256("river.state.version") - 1` =
`0x82055909238c0f5e63d6f174068ebb8f51bcec9bd37de63bb68f6551feec0cfc`.

The `init(N)` modifier requires the counter to equal `N` at call time and sets it to `N + 1`.

Pectra (v2.0.0) reinitializers — run atomically as part of this upgrade:

| Proxy | Reinitializer | `init(N)` | Expected counter **before** | Counter **after** |
|---|---|---|---|---|
| Withdraw | `initWithdrawV1_1(pectraWithdrawal, pectraConsolidation, operatorsRegistry, attestationVerifier)` | `init(1)` | `1` | `2` |
| OperatorsRegistry | `initOperatorsRegistryV1_2(withdrawAddress)` | `init(2)` | `2` | `3` |
| River | `initRiverV1_3(withdrawalCredentials, consolidationCoverageFund, attestationVerifier, externalConsolidationRecipientMapping, consolidator)` | `init(3)` | `3` | `4` |

Already-consumed reinitializers (shipped on mainnet in prior versions — do **not** re-run; listed so
the atomic rule is understood to apply to the whole `init*` family, not just the three Pectra
hooks): `initAllowlistV1_1` `init(1)`, `initOracleV1_1` `init(1)`,
`initializeRedeemManagerV1_2` `init(1)`.

## Pre-flight checks (before submitting the upgrade)

For each proxy to be initialized, confirm the on-chain version counter equals the expected
pre-upgrade value from the table above:

```sh
# Version counter (expect the "before" value: Withdraw=1, OperatorsRegistry=2, River=3)
cast storage <PROXY_ADDRESS> \
  0x82055909238c0f5e63d6f174068ebb8f51bcec9bd37de63bb68f6551feec0cfc \
  --rpc-url "$RPC_URL"

# ERC1967 proxy admin (this address — the ProxyFirewall — must be the sender of upgradeToAndCall)
cast storage <PROXY_ADDRESS> \
  0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 \
  --rpc-url "$RPC_URL"
```

## Execution assertion (review the upgrade transaction batch)

Before signing / submitting, inspect the full transaction batch (e.g. the Safe bundle) and verify:

- Every implementation change targeting a proxy that needs initialization is a
  `upgradeToAndCall(newImplementation, initCalldata)` call — **not** a bare `upgradeTo`.
- `initCalldata` decodes to the intended `init*` selector **with the intended production
  arguments** (decode and eyeball each address; do not trust the raw bytes).
- There is **no** standalone transaction whose target is a proxy and whose selector is any
  `init*` / `initialize*` selector.
- Each `upgradeToAndCall` is sent by that proxy's ERC1967 admin (the ProxyFirewall from the
  pre-flight read).

## Post-flight checks (after the upgrade lands)

For each initialized proxy:

- Version counter incremented to the expected "after" value (Withdraw=2, OperatorsRegistry=3,
  River=4) — read the same version slot as above.
- Spot-check that the addresses/state set by the initializer match the intended production values
  (guards against a silent misconfiguration even under an atomic upgrade). Read the relevant
  storage slots or getters, e.g.:
  - Withdraw: `withdraw.state.pectraWithdrawalContractAddress`,
    `withdraw.state.pectraConsolidationContractAddress`, `river.state.operatorsRegistryAddress`,
    `river.state.attestationVerifierAddress` (each `keccak256(name) - 1`).
  - OperatorsRegistry: `river.state.withdrawAddress` (`keccak256(name) - 1`).
  - River: `getConsolidationCoverageFund()`, `getConsolidator()`, and
    `river.state.attestationVerifierAddress` / `river.state.consolidationCoverageFundAddress` /
    `river.state.externalConsolidationRecipientMappingAddress` (`keccak256(name) - 1`).

## Regression coverage

`contracts/test/fork/mainnet/5.pectraReinitializerAtomicUpgrade.t.sol` reproduces the production
atomic `upgradeToAndCall` sequence for all three Pectra reinitializers, demonstrates that a
non-atomic (`upgradeTo` + separate init) sequence is front-runnable, and asserts the reinitializers
cannot be re-run. Run it against a mainnet fork before the upgrade:

```sh
MAINNET_FORK_RPC_URL=<archive-rpc> forge test \
  --match-path 'test/fork/mainnet/5.pectraReinitializerAtomicUpgrade.t.sol' -vvv
```
