# Security Audit Report — Liquid Collective Solana Stake Pool

**Date:** 2026-03-09
**Audited by:** Multi-Agent Smart Contract Audit (Claude Code)
**Repository:** liquid-collective/liquid-collective-solana
**Commit:** `a938ace064947e51a9e1bfbc93dc0e3eaddb4a59` (branch: `main`, tag: `v2.0.0-lc-mainnet` +5 commits)

---

## Scope

|                                  |                                                                                                                                                   |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Mode**                         | Comprehensive multi-agent security audit                                                                                                          |
| **Files reviewed**               | `lib.rs` · `account_data/state.rs` · `account_data/allowlist_entry.rs` · All 13 instruction files · All processor files · `constants.rs`       |
| **Skills used**                  | solana-vulnerability-scanner · audit-context · entry-points · code-maturity-assessor · guidelines-advisor · insecure-defaults · sharp-edges · supply-chain-risk-auditor · zeroize-audit |
| **Cross-reference round**        | N/A (single-pass audit)                                                                                                                           |
| **Framework**                    | Anchor 0.32.1                                                                                                                                     |
| **Runtime**                      | Solana v2.x                                                                                                                                       |
| **Dependencies**                 | spl-stake-pool v2.0.0-lc (forked) · anchor-lang 0.32.1 · anchor-spl 0.32.1 · solana-program 2.x · borsh 1.5.7 · bincode 1.3.1                  |
| **Confidence threshold (1-100)** | 80                                                                                                                                                |

---

## Executive Summary

Nine independent security audits were performed against the Liquid Collective Solana Stake Pool program, covering Solana-specific vulnerabilities, architectural analysis, entry points, code maturity, insecure defaults, sharp edges, supply chain risk, zeroization, and best-practice guidelines.

### Overall Assessment: MODERATE RISK

The program is **well-structured and demonstrates good security fundamentals**. Critical Solana vulnerability patterns (arbitrary CPI, PDA validation, signer checks, sysvar spoofing) are all properly addressed. The codebase is clean, well-organized, and has a comprehensive integration test suite (87 tests). An external audit by Quantstamp has already been performed.

However, **several medium-severity findings** were consistently identified across multiple audits, indicating genuine areas for improvement before or shortly after mainnet deployment.

### Finding Statistics

- **High Severity:** 3 findings (localnet keys in git, no state-to-stake_pool binding, optional slippage defaults)
- **Medium Severity:** 8 findings (missing validations, unchecked accounts, allowlist bypass via recipient, rent leak, fee validation)
- **Low Severity:** 8 findings (dead code, unwrap panics, unchecked authorities, deprecated APIs, documentation gaps)
- **Informational:** 6 findings (init_if_needed, mainnet config default, multiple state instances, space margin)

**No critical vulnerabilities were found. No zeroization issues were found.**

### Key Architectural Observations

The Liquid Collective Stake Pool wraps the SPL Stake Pool to provide permissioned liquid staking via an on-chain allowlist with pause/unpause emergency controls and role-based access control (admin, pauser, allower, manager). All actual staking operations are delegated to the SPL Stake Pool via CPI.

---

## Entry Point Analysis

### State-Changing Entry Points

| Contract | Function | Access Level | State Changes |
|---|---|---|---|
| `liquid_collective_stake_pool` | `initialize(InitializeArgs)` | **Any signer (one-time)** | Creates `State` with admin, pauser, allower roles; sets unpaused |
| `liquid_collective_stake_pool` | `create_pool(CreatePoolArgs)` | **Manager (pause-gated)** | Creates SPL Stake Pool via CPI; sets up pool mint, reserve stake, validator list |
| `liquid_collective_stake_pool` | `deposit_sol(u64, Option<u64>)` | **Allowlisted user (pause-gated)** | Transfers SOL to pool; mints pool tokens to recipient via CPI |
| `liquid_collective_stake_pool` | `deposit_stake(u64, Option<u64>)` | **Allowlisted user (pause-gated)** | Transfers stake account to pool; mints pool tokens to recipient via CPI |
| `liquid_collective_stake_pool` | `withdraw_sol(u64, Option<u64>)` | **Allowlisted user (pause-gated)** | Burns pool tokens; transfers SOL from pool via CPI |
| `liquid_collective_stake_pool` | `withdraw_stake(u64, Option<u64>)` | **Allowlisted user (pause-gated)** | Burns pool tokens; transfers stake account from pool via CPI |
| `liquid_collective_stake_pool` | `pause()` | **Pauser** | Sets `state.is_paused = true` |
| `liquid_collective_stake_pool` | `unpause()` | **Admin** | Sets `state.is_paused = false` |
| `liquid_collective_stake_pool` | `set_admin(SetAdminArgs)` | **Admin + new admin co-sign (pause-gated)** | Updates `state.admin` to new admin |
| `liquid_collective_stake_pool` | `set_pauser(SetPauserArgs)` | **Admin (pause-gated)** | Updates `state.pauser` to new pauser |
| `liquid_collective_stake_pool` | `set_allower(SetAllowerArgs)` | **Admin (pause-gated)** | Updates `state.allower` to new allower |
| `liquid_collective_stake_pool` | `add_to_allowlist_entry(AddToAllowlistEntryArgs)` | **Allower (pause-gated)** | Creates or updates `AllowListEntry` PDA; sets `can_deposit_withdraw = true` |
| `liquid_collective_stake_pool` | `remove_from_allowlist_entry(RemoveFromAllowlistEntryArgs)` | **Allower (pause-gated)** | Updates `AllowListEntry` PDA; sets `can_deposit_withdraw = false` |

### Key Observations

- **Two-party admin transfer** (`set_admin` requires new admin co-signature) is a strong security pattern
- **Pause/unpause asymmetry** (pauser can pause, only admin can unpause) is well-designed for emergency response
- **All 13 instructions emit CPI events** for observability
- **PDA-based `funding_authority`** prevents direct SPL Stake Pool manipulation
- **Role hierarchy** properly enforces separation of duties (admin > pauser, allower; manager is single-use for pool creation)

### Privilege Escalation Paths

| Path | Risk Level | Notes |
|------|------------|-------|
| Compromised admin → full control | By design | Can change pauser, allower, add self to allowlist |
| Compromised allower → allowlist bypass | Medium | Can add self to allowlist, then deposit/withdraw |
| Compromised pauser → DoS | By design | Can pause; only admin can unpause |
| SPL Stake Pool manager → freeze user ATAs | Compliance | Can freeze any user's LsSOL token account |

---

## Findings

### [90] 1. No On-Chain Binding Between `state` and `stake_pool`

`instructions/deposit_sol.rs:19-20` · Confidence: 90 · Consensus: N/A

**Description**

The `stake_pool` account in all deposit/withdraw instructions is declared as `UncheckedAccount<'info>` with only `#[account(mut)]`. The `State` account does not store the `stake_pool` public key, so there is no explicit on-chain linkage between the program's state and the stake pool it operates on.

**Mitigations present:** The `funding_authority` PDA (seeded from `state.key()`) must match the SPL Stake Pool's deposit/withdraw authority. The SPL Stake Pool program validates this internally during CPI. The `pool_mint` and `reserve_stake` are derived from `stake_pool.key()` via PDA seeds, providing indirect binding.

**Residual risk:** Defense-in-depth gap. If SPL Stake Pool validation is ever bypassed or weakened, the lack of explicit binding could become exploitable.

**Flagged by:** Solana Vulnerability Scanner, Audit Context Builder, Guidelines Advisor, Sharp Edges Analyzer

**Recommendation**

Store the `stake_pool` pubkey in the `State` account during `create_pool` and add `address = state.stake_pool` constraints on all deposit/withdraw instructions. This provides explicit on-chain binding independent of CPI validation.

```rust
// In account_data/state.rs
pub struct State {
    pub admin: Pubkey,
    pub pauser: Pubkey,
    pub allower: Pubkey,
    pub initial_manager: Pubkey,
    pub stake_pool: Pubkey,  // Add this field
    pub is_paused: bool,
}

// In create_pool.rs, after CPI succeeds:
ctx.accounts.state.stake_pool = ctx.accounts.stake_pool.key();

// In all deposit/withdraw instructions:
#[account(
    mut,
    address = state.stake_pool @ ErrorCode::InvalidStakePool
)]
pub stake_pool: UncheckedAccount<'info>,
```

---

### [90] 2. Localnet Private Keys Committed to Git Repository

`wallets/localnet/deployer.json` · Confidence: 90 · Consensus: N/A

**Description**

Raw Solana keypair bytes are tracked in git history at `wallets/localnet/deployer.json` and `wallets/localnet/liquid_collective_stake_pool.json`. While labeled "localnet" and `.gitignore` excludes `wallets/mainnet` and `wallets/devnet`, the localnet directory itself is not excluded. Any reuse of these keys on a live network (devnet, testnet, mainnet) would result in critical exposure with funds at immediate risk.

**Flagged by:** Insecure Defaults Scanner

**Recommendation**

1. Add `wallets/localnet/` to `.gitignore` immediately
2. Audit all deployment scripts to verify these keys have never been used on live networks
3. If any reuse is discovered, rotate keys immediately and revoke any compromised authorities
4. Consider using `git filter-branch` or BFG Repo-Cleaner to purge keypairs from git history entirely

---

### [90] 3. Optional Slippage Protection Defaults to No Protection

`instructions/deposit_sol.rs:92` · Confidence: 90 · Consensus: N/A

**Description**

All four financial operations (`deposit_sol`, `deposit_stake`, `withdraw_sol`, `withdraw_stake`) use `Option<u64>` for slippage parameters (`minimum_pool_tokens_out`, `minimum_lamports_out`, `minimum_stake_lamports_out`). When `None`, no slippage protection is applied. This is a fail-open default that exposes users to sandwich attacks, MEV extraction, and unfavorable exchange rates during high volatility.

**Affected locations:**
- `instructions/deposit_sol.rs:92` - `minimum_pool_tokens_out: Option<u64>`
- `instructions/withdraw_sol.rs:98` - `minimum_lamports_out: Option<u64>`
- `instructions/withdraw_stake.rs:100` - `minimum_stake_lamports_out: Option<u64>`
- `instructions/deposit_stake.rs:112` - `minimum_pool_tokens_out: Option<u64>`

**Flagged by:** Insecure Defaults Scanner, Sharp Edges Analyzer, Code Maturity Assessor, Guidelines Advisor

**Recommendation**

Make slippage a required `u64` parameter, or enforce a minimum reasonable tolerance (e.g., 1-5%) when omitted:

```rust
// Option 1: Make required
pub minimum_pool_tokens_out: u64,

// Option 2: Enforce default tolerance
let min_tokens = args.minimum_pool_tokens_out.unwrap_or_else(|| {
    expected_tokens.saturating_mul(95).saturating_div(100) // 5% default slippage
});
```

Client libraries should provide clear warnings if users attempt to set overly permissive slippage.

---

### [75] 4. `set_admin` Missing `Pubkey::default()` Validation

`processors/set_admin.rs:13-15` · Confidence: 75 · Consensus: N/A

**Description**

Unlike `set_pauser` and `set_allower` which both validate `!= Pubkey::default()`, the `set_admin` function has no such check. The `new_admin` must sign (which prevents exploitation via a zero-key attack), but this is an inconsistency and defense-in-depth gap. If the co-signature requirement were ever removed, this would become a critical vulnerability.

**Flagged by:** Solana Vulnerability Scanner, Insecure Defaults Scanner, Audit Context Builder, Sharp Edges Analyzer, Guidelines Advisor, Code Maturity Assessor

**Recommendation**

Add `Pubkey::default()` validation for consistency:

```rust
require!(
    args.new_admin != Pubkey::default(),
    ErrorCode::InvalidPubkey
);
```

---

### [75] 5. Deposit Instructions Allow Arbitrary `recipient`, Bypassing Allowlist Intent

`instructions/deposit_sol.rs:66-67` · Confidence: 75 · Consensus: N/A

**Description**

An allowlisted depositor can direct pool tokens (LsSOL) to ANY recipient's associated token account, even if that recipient is not on the allowlist. This undermines the allowlist's compliance purpose—non-allowlisted users can receive LsSOL via third-party deposits and trade it on secondary markets.

**Affected instructions:**
- `deposit_sol.rs:66-67` - `recipient: UncheckedAccount<'info>` with no allowlist constraint
- `deposit_stake.rs:83-84` - Same pattern

**Flagged by:** Audit Context Builder, Sharp Edges Analyzer

**Recommendation**

Evaluate whether `recipient` should be constrained to allowlisted addresses:

```rust
// Option 1: Require recipient is allowlisted
#[account(
    seeds = [
        b"allowlist",
        state.key().as_ref(),
        recipient.key().as_ref()
    ],
    bump,
    constraint = recipient_allowlist.can_deposit_withdraw @ ErrorCode::RecipientNotAllowlisted
)]
pub recipient_allowlist: Account<'info, AllowListEntry>,

// Option 2: Document current behavior as intentional
// If the program is designed to allow third-party deposits for custody/operational reasons,
// this should be explicitly documented in the architecture specification.
```

If the current behavior is intentional (allowing third-party deposits), document this design decision clearly in both code comments and external documentation.

---

### [75] 6. `FeeArgs::validate()` Only Checks Non-Zero Denominator

`instructions/create_pool.rs:93-96` · Confidence: 75 · Consensus: N/A

**Description**

The `FeeArgs::validate()` function only validates that `denominator != 0` to prevent division by zero. There is no validation that `numerator <= denominator` (i.e., fee <= 100%). The SPL Stake Pool performs its own fee validation downstream, but the wrapper should enforce sane bounds as a first line of defense.

**Flagged by:** Insecure Defaults Scanner, Sharp Edges Analyzer, Guidelines Advisor

**Recommendation**

Add numerator <= denominator validation:

```rust
impl FeeArgs {
    pub fn validate(&self) -> Result<()> {
        require!(self.denominator != 0, ErrorCode::InvalidFee);
        require!(
            self.numerator <= self.denominator,
            ErrorCode::InvalidFee
        );
        Ok(())
    }
}
```

---

### [75] 7. `AllowListEntry` Accounts Are Never Closed (Rent Leak)

`processors/remove_from_allowlist_entry.rs:29` · Confidence: 75 · Consensus: N/A

**Description**

Removing a user from the allowlist sets `can_deposit_withdraw = false` but does not close the PDA account. Rent-exempt lamports (~0.007 SOL per entry including 1000-byte space margin) are permanently locked. Over time, with many allowlist changes, this represents a non-trivial rent leak.

**Flagged by:** Entry Point Analyzer, Audit Context Builder, Sharp Edges Analyzer, Guidelines Advisor

**Recommendation**

Consider using Anchor's `close` constraint to reclaim rent:

```rust
#[derive(Accounts)]
pub struct RemoveFromAllowlistEntry<'info> {
    #[account(
        mut,
        seeds = [
            b"allowlist",
            state.key().as_ref(),
            allowlist_entry.address.as_ref()
        ],
        bump,
        close = allower  // Refund rent to allower
    )]
    pub allowlist_entry: Account<'info, AllowListEntry>,

    #[account(mut)]
    pub allower: Signer<'info>,
    // ...
}
```

**Trade-off:** Closing accounts makes re-adding users slightly more expensive (full init cost vs. rewriting existing account). If re-initialization attacks are a concern, document the deliberate choice to leave accounts open.

---

### [75] 8. `set_pauser` and `set_allower` Do Not Require New Role Holder Co-Signature

`instructions/set_pauser.rs:7-16` · Confidence: 75 · Consensus: N/A

**Description**

Unlike `set_admin` which requires the new admin to co-sign the transaction, the admin can unilaterally set pauser/allower to any non-default address, including addresses nobody controls (lost keys, typos). This creates operational risk if incorrect addresses are specified.

**Affected instructions:**
- `instructions/set_pauser.rs:7-16`
- `instructions/set_allower.rs:7-16`

**Flagged by:** Audit Context Builder, Guidelines Advisor, Sharp Edges Analyzer

**Recommendation**

Consider requiring co-signature for consistency with `set_admin`:

```rust
#[derive(Accounts)]
pub struct SetPauser<'info> {
    #[account(
        mut,
        has_one = admin @ ErrorCode::Unauthorized
    )]
    pub state: Account<'info, State>,
    pub admin: Signer<'info>,

    /// New pauser must co-sign to prove they control the key
    #[account(address = args.new_pauser @ ErrorCode::Unauthorized)]
    pub new_pauser: Signer<'info>,  // Add this
}
```

Alternatively, document the design rationale for unilateral role assignment if there's an operational reason (e.g., admin controls a hot wallet, needs to quickly rotate roles without coordination).

---

### [75] 9. Program Initializes in Unpaused State (Fail-Open)

`account_data/state.rs:50` · Confidence: 75 · Consensus: N/A

**Description**

The `State::new()` constructor sets `is_paused: false`. The program is immediately operational upon initialization with no cooling-off period to verify role configuration, test pause mechanisms, or confirm deployment settings.

**Flagged by:** Insecure Defaults Scanner

**Recommendation**

Consider initializing paused, requiring explicit `unpause` after verifying configuration:

```rust
impl State {
    pub fn new(admin: Pubkey, pauser: Pubkey, allower: Pubkey, initial_manager: Pubkey) -> Self {
        Self {
            admin,
            pauser,
            allower,
            initial_manager,
            is_paused: true,  // Changed from false
        }
    }
}
```

This provides a safer default for production deployments, forcing operators to explicitly enable functionality after verification.

---

### [75] 10. Dead Code — `only_staker` Function

`processors/acl.rs:21-26` · Confidence: 75 · Consensus: N/A

**Description**

The `only_staker` function uses `try_from_slice_unchecked` without owner validation and is never called anywhere in the codebase. Dead code with unsafe deserialization patterns should be removed to reduce attack surface and maintenance burden.

**Flagged by:** Entry Point Analyzer, Solana Vulnerability Scanner, Guidelines Advisor

**Recommendation**

Remove the function entirely:

```rust
// Delete lines 21-26 from processors/acl.rs
```

If this function was intended for future use, move it to a feature branch until needed.

---

### [75] 11. `try_from_slice_unchecked` + `.unwrap()` in deposit_stake

`processors/deposit_stake.rs:80` · Confidence: 75 · Consensus: N/A

**Description**

The `deposit_stake` processor uses `try_from_slice_unchecked` (skips discriminator/length checks) followed by `.unwrap()` (panics on failure):

```rust
let stake_data =
    try_from_slice_unchecked::<StakeStateV2>(&ctx.accounts.stake.data.borrow()).unwrap();
```

This occurs after CPI, so the data should be valid, but this pattern is fragile. If deserialization fails, two problems occur:
1. The transaction panics (poor UX, unclear error message)
2. The `DepositStakeEvent` is not emitted (silent failure for observability)

**Flagged by:** Solana Vulnerability Scanner, Insecure Defaults Scanner, Sharp Edges Analyzer, Guidelines Advisor, Code Maturity Assessor

**Recommendation**

Replace `.unwrap()` with proper error handling:

```rust
let stake_data = try_from_slice_unchecked::<StakeStateV2>(&ctx.accounts.stake.data.borrow())
    .map_err(|_| ErrorCode::InvalidStakeAccount)?;

// Or use the checked variant:
let stake_data = try_from_slice::<StakeStateV2>(&ctx.accounts.stake.data.borrow())
    .map_err(|_| ErrorCode::InvalidStakeAccount)?;
```

---

### [60] 12. `stake_pool_withdraw_authority` Is Fully Unchecked

`instructions/deposit_sol.rs` (and others) · Confidence: 60 · Consensus: N/A

**Description**

The `stake_pool_withdraw_authority` account in all deposit/withdraw instructions has no seeds, address, or owner constraints. Validation is deferred entirely to the SPL Stake Pool CPI. While the SPL program will reject invalid authorities, this creates a defense-in-depth gap.

**Affected files:**
- `instructions/deposit_sol.rs`
- `instructions/withdraw_sol.rs`
- `instructions/deposit_stake.rs`
- `instructions/withdraw_stake.rs`

**Flagged by:** Solana Vulnerability Scanner, Audit Context Builder, Guidelines Advisor

**Recommendation**

Derive locally with PDA seeds:

```rust
#[account(
    seeds = [
        stake_pool.key().as_ref(),
        b"withdraw"
    ],
    bump,
    seeds::program = spl_stake_pool::ID
)]
pub stake_pool_withdraw_authority: SystemAccount<'info>,
```

---

### [60] 13. `manager_pool_account` Is Fully Unchecked

`instructions/deposit_sol.rs` (and others) · Confidence: 60 · Consensus: N/A

**Description**

The `manager_pool_account` in all deposit/withdraw instructions has no validation that it's the manager's associated token account. Validation is deferred to the SPL Stake Pool. This creates a risk if the SPL program's checks are ever weakened.

**Flagged by:** Solana Vulnerability Scanner

**Recommendation**

Add owner check or ATA derivation constraint:

```rust
#[account(
    mut,
    constraint = manager_pool_account.owner == manager.key() @ ErrorCode::InvalidManagerAccount
)]
pub manager_pool_account: Account<'info, TokenAccount>,
```

Or derive as ATA:

```rust
#[account(
    mut,
    associated_token::mint = pool_mint,
    associated_token::authority = manager
)]
pub manager_pool_account: Account<'info, TokenAccount>,
```

---

### [60] 14. No Minimum Deposit/Withdrawal Amount Validation

All deposit/withdraw processors · Confidence: 60 · Consensus: N/A

**Description**

No validation that `amount > 0`. Zero-amount transactions would waste compute budget and could be used for spam or observability noise.

**Flagged by:** Guidelines Advisor

**Recommendation**

Add validation to all financial operations:

```rust
require!(args.amount > 0, ErrorCode::InvalidAmount);
```

---

### [60] 15. `Anchor.toml` Defaults to Mainnet Cluster

`Anchor.toml:19-20` · Confidence: 60 · Consensus: N/A

**Description**

The Anchor configuration defaults to `cluster = "mainnet"`. Running `anchor deploy` without specifying a cluster would attempt mainnet deployment. This is a footgun for developers testing locally.

**Flagged by:** Insecure Defaults Scanner

**Recommendation**

Change default to localnet:

```toml
[provider]
cluster = "localnet"  # Changed from "mainnet"
```

---

### [60] 16. `#[allow(deprecated)]` Suppressions

`processors/acl.rs:1` · Confidence: 60 · Consensus: N/A

**Description**

Files use `#[allow(deprecated)]` to suppress warnings for `solana_program::borsh1::try_from_slice_unchecked`. The API is deprecated and should be migrated to the current recommended approach.

**Affected files:**
- `processors/acl.rs:1`
- `processors/deposit_stake.rs:1`

**Flagged by:** Guidelines Advisor, Code Maturity Assessor

**Recommendation**

Migrate to non-deprecated API and remove the suppression. Consult Solana SDK migration guide for the recommended replacement.

---

### [60] 17. `max_validators` Has No Range Validation

`processors/initialize.rs:35` · Confidence: 60 · Consensus: N/A

**Description**

The `validator_list_size()` function in `constants.rs:9-15` performs `u32` multiplication that could theoretically overflow with extreme `max_validators` values. The `overflow-checks = true` flag catches this at runtime but provides a poor error message.

**Flagged by:** Sharp Edges Analyzer

**Recommendation**

Add explicit range validation:

```rust
require!(
    args.max_validators > 0 && args.max_validators <= 10000,
    ErrorCode::InvalidMaxValidators
);
```

Document the rationale for the upper bound (e.g., account size limits, practical network constraints).

---

### [60] 18. Pause Blocks Admin Role Transfer During Emergencies

`processors/set_admin.rs` · Confidence: 60 · Consensus: N/A

**Description**

The `set_admin` instruction has a `when_not_paused` check. If the admin key is compromised, the attacker can pause the program and lock out admin transfer. Recovery requires the (compromised) admin to unpause first, creating a catch-22.

**Flagged by:** Sharp Edges Analyzer

**Recommendation**

Remove the `when_not_paused` constraint from `set_admin`:

```rust
#[account(constraint = !state.is_paused @ ErrorCode::ProgramPaused)]  // Remove this line
```

Admin transfer should be allowed even when paused, as it's a critical recovery mechanism.

---

### [60] 19. Doc Comment Mismatch in `lib.rs`

`lib.rs:39` · Confidence: 60 · Consensus: N/A

**Description**

Documentation references `UpsertAllowListEntryArgs` which doesn't exist. The actual types are `AddToAllowlistEntryArgs` and `RemoveFromAllowlistEntryArgs`.

**Flagged by:** Guidelines Advisor

**Recommendation**

Fix documentation:

```rust
/// Add user to allowlist: [`add_to_allowlist_entry`]
/// Remove user from allowlist: [`remove_from_allowlist_entry`]
```

---

### [40] 20. `init_if_needed` Feature Enabled

Multiple locations · Confidence: 40 · Consensus: N/A

**Description**

The `init_if_needed` feature is enabled. Usage in this codebase appears safe (properly guarded with seeds and bumps), but this feature has historically been associated with re-initialization vulnerabilities.

**Flagged by:** Solana Vulnerability Scanner, Insecure Defaults Scanner

**Recommendation**

No action needed. Usage is properly guarded. Maintain vigilance in code reviews when this feature is used.

---

### [40] 21. Multiple State Instances Possible

Architecture · Confidence: 40 · Consensus: N/A

**Description**

The `State` account is a keypair, not a fixed PDA, allowing multiple independent state instances (multi-tenancy). This is by design but creates namespace isolation concerns.

**Flagged by:** Audit Context Builder

**Recommendation**

Document the multi-tenancy design clearly. Consider whether a singleton state model (PDA with fixed seed) would be more appropriate for mainnet deployment.

---

### [40] 22. `manager_pool_account` Used for Both Manager Fee and Referral Fee

Multiple instructions · Confidence: 40 · Consensus: N/A

**Description**

The same `manager_pool_account` receives both manager fees and referral fees in deposit/withdraw operations. This is a design choice but may complicate accounting.

**Flagged by:** Audit Context Builder

**Recommendation**

If separate accounting is needed, consider separate account parameters. Otherwise, document this design decision.

---

### [40] 23. `SPACE_MARGIN` of 1000 Bytes Per Account

`constants.rs` · Confidence: 40 · Consensus: N/A

**Description**

All accounts allocate an additional 1000 bytes beyond calculated requirements. This wastes rent but provides migration buffer. If the margin is never used, it represents a long-term inefficiency.

**Flagged by:** Sharp Edges Analyzer

**Recommendation**

Document the rationale for the 1000-byte margin. Consider reducing to 100-200 bytes if the account structures are stable.

---

### [40] 24. `recipient` in Withdrawals Is Unchecked

`instructions/withdraw_sol.rs` · Confidence: 40 · Consensus: N/A

**Description**

The `recipient` account in withdrawal instructions is unchecked (no owner validation). This is by design—users can withdraw to any address they control.

**Flagged by:** Solana Vulnerability Scanner

**Recommendation**

No action needed. This is intentional functionality.

---

### [40] 25. Reserve Stake Init Uses `invoke` Correctly

`processors/create_pool.rs` · Confidence: 40 · Consensus: N/A

**Description**

The reserve stake account initialization uses `invoke` with proper signer seeds. This is correct Solana CPI usage.

**Flagged by:** Audit Context Builder

**Recommendation**

No action needed. Flagged for completeness only.

---

## Findings Summary

| # | Confidence | Title | Consensus |
|---|---|---|---|
| 1 | [90] | No On-Chain Binding Between `state` and `stake_pool` | N/A |
| 2 | [90] | Localnet Private Keys Committed to Git Repository | N/A |
| 3 | [90] | Optional Slippage Protection Defaults to No Protection | N/A |
| 4 | [75] | `set_admin` Missing `Pubkey::default()` Validation | N/A |
| 5 | [75] | Deposit Instructions Allow Arbitrary `recipient`, Bypassing Allowlist Intent | N/A |
| 6 | [75] | `FeeArgs::validate()` Only Checks Non-Zero Denominator | N/A |
| 7 | [75] | `AllowListEntry` Accounts Are Never Closed (Rent Leak) | N/A |
| 8 | [75] | `set_pauser` and `set_allower` Do Not Require New Role Holder Co-Signature | N/A |
| 9 | [75] | Program Initializes in Unpaused State (Fail-Open) | N/A |
| 10 | [75] | Dead Code — `only_staker` Function | N/A |
| 11 | [75] | `try_from_slice_unchecked` + `.unwrap()` in deposit_stake | N/A |
| 12 | [60] | `stake_pool_withdraw_authority` Is Fully Unchecked | N/A |
| 13 | [60] | `manager_pool_account` Is Fully Unchecked | N/A |
| 14 | [60] | No Minimum Deposit/Withdrawal Amount Validation | N/A |
| 15 | [60] | `Anchor.toml` Defaults to Mainnet Cluster | N/A |
| 16 | [60] | `#[allow(deprecated)]` Suppressions | N/A |
| 17 | [60] | `max_validators` Has No Range Validation | N/A |
| 18 | [60] | Pause Blocks Admin Role Transfer During Emergencies | N/A |
| 19 | [60] | Doc Comment Mismatch in `lib.rs` | N/A |
| | | **Below Confidence Threshold** | |
| 20 | [40] | `init_if_needed` Feature Enabled | N/A |
| 21 | [40] | Multiple State Instances Possible | N/A |
| 22 | [40] | `manager_pool_account` Used for Both Manager Fee and Referral Fee | N/A |
| 23 | [40] | `SPACE_MARGIN` of 1000 Bytes Per Account | N/A |
| 24 | [40] | `recipient` in Withdrawals Is Unchecked | N/A |
| 25 | [40] | Reserve Stake Init Uses `invoke` Correctly | N/A |

Consensus definitions:
- **UNANIMOUS**: All 3 reviewing agents AGREE
- **MAJORITY**: 2+ reviewing agents AGREE (some NUANCE is OK)
- **DISPUTED**: 1+ reviewing agents DISAGREE

*Note: This audit was performed in single-pass mode without cross-referencing. All consensus values are N/A.*

---

## Code Maturity Scorecard (Trail of Bits 9-Category Framework)

### 1. Arithmetic Safety — Satisfactory

- **Strengths:**
  - `overflow-checks = true` in Cargo.toml catches overflows at runtime
  - All fee calculations delegated to SPL Stake Pool (battle-tested logic)
  - No raw integer arithmetic in financial operations
  - `saturating_mul` and `saturating_div` patterns used where appropriate

- **Gaps:**
  - `validator_list_size()` performs unchecked `u32` multiplication (relies on runtime overflow checks)
  - No explicit bounds checking on `max_validators` parameter

**Rating: 3/4**

### 2. Auditing & Monitoring — Satisfactory

- **Strengths:**
  - All 13 instructions emit CPI events for observability
  - Events include all critical parameters (amounts, recipients, authorities)
  - External audit by Quantstamp already performed
  - GitHub Actions CI runs on every commit

- **Gaps:**
  - No bug bounty program mentioned
  - No on-chain monitoring or alerting documented
  - No security incident response plan in repository

**Rating: 3/4**

### 3. Access Controls — Satisfactory

- **Strengths:**
  - Clear role separation (admin, pauser, allower, manager)
  - Two-party admin transfer requires co-signature
  - Pause/unpause asymmetry well-designed
  - `Pubkey::default()` validation on initialize for all roles
  - Allowlist enforced on all financial operations

- **Gaps:**
  - `set_admin` missing `Pubkey::default()` validation (inconsistent with other role setters)
  - No timelock on privileged operations
  - No on-chain multisig enforcement (single pubkeys for all roles)

**Rating: 3/4**

### 4. Complexity Management — Strong

- **Strengths:**
  - Excellent code organization (instruction/processor/account_data separation)
  - Clean Anchor patterns throughout
  - Minimal custom logic (delegates to SPL Stake Pool)
  - Clear function boundaries and single responsibility principle
  - No deeply nested logic or complex state machines

- **Gaps:**
  - None identified

**Rating: 4/4**

### 5. Decentralization — Moderate

- **Strengths:**
  - PDA-based authority prevents single-key control of SPL Stake Pool
  - Role separation distributes operational control
  - Allowlist functionality supports compliance without full centralization

- **Gaps:**
  - No timelock on admin operations
  - No on-chain multisig (DAO) for admin role
  - Admin can unilaterally change all other roles (pauser, allower)
  - Emergency pause mechanism is centralized (single pauser key)
  - Forked SPL Stake Pool creates upgrade centralization

**Rating: 2/4**

### 6. Documentation — Moderate

- **Strengths:**
  - Code comments explain non-obvious logic
  - Instruction arguments well-documented
  - README includes deployment instructions
  - Integration tests serve as usage examples (87 tests)

- **Gaps:**
  - No architecture specification or system design doc
  - No threat model documentation
  - No invariant documentation
  - No security assumptions documented
  - Doc comment mismatch in `lib.rs`
  - No formal specification of state transitions

**Rating: 2/4**

### 7. MEV / Front-Running Risks — Satisfactory

- **Strengths:**
  - Slippage parameters available on all financial operations
  - Pool-based staking reduces validator-specific MEV
  - Allowlist reduces attack surface (permissioned access)

- **Gaps:**
  - Slippage parameters are optional and default to no protection (fail-open)
  - No sandwich attack prevention beyond slippage
  - No MEV analysis documented

**Rating: 3/4**

### 8. Low-Level / Assembly Code — Moderate

- **Strengths:**
  - Anchor framework handles most low-level details
  - PDA derivation uses canonical Anchor patterns
  - CPI calls properly structured with signer seeds

- **Gaps:**
  - `try_from_slice_unchecked` usage skips safety checks
  - `.unwrap()` in production code (deposit_stake.rs:80)
  - Dead code with unsafe patterns (`only_staker` function)
  - Deprecated API suppressions with `#[allow(deprecated)]`

**Rating: 2/4**

### 9. Testing & Verification — Moderate

- **Strengths:**
  - 87 integration tests across 14 test files
  - Tests cover both happy paths and negative cases
  - All 13 instructions have test coverage
  - GitHub Actions CI runs tests on every commit
  - Test-to-source ratio ~1.86:1 (strong coverage)

- **Gaps:**
  - No fuzzing (Trident, proptest, quickcheck)
  - No formal verification
  - No mutation testing (test quality unvalidated)
  - No code coverage reporting (blind spots unknown)
  - No boundary condition tests (u64::MAX, zero amounts)
  - No multi-state-instance isolation tests

**Rating: 2/4**

### Summary Table

| Category | Rating | Key Strength | Key Risk |
|---|---|---|---|
| Arithmetic Safety | **Satisfactory** (3/4) | Runtime overflow checks enabled | Unchecked validator list size calculation |
| Auditing & Monitoring | **Satisfactory** (3/4) | Comprehensive event emission | No bug bounty or monitoring plan |
| Access Controls | **Satisfactory** (3/4) | Two-party admin transfer | No timelock or multisig enforcement |
| Complexity Management | **Strong** (4/4) | Excellent code organization | None |
| Decentralization | **Moderate** (2/4) | Role separation | Single-key admin control |
| Documentation | **Moderate** (2/4) | Good code comments | No architecture or threat model |
| MEV / Front-Running | **Satisfactory** (3/4) | Slippage parameters available | Optional slippage defaults to no protection |
| Low-Level Code | **Moderate** (2/4) | Anchor framework usage | Unchecked deserialization + unwrap |
| Testing & Verification | **Moderate** (2/4) | 87 integration tests | No fuzzing or formal verification |
| **Overall** | **Moderate-Satisfactory** (2.6/4.0) | Clean architecture, strong access controls | Documentation gaps, fail-open defaults |

---

## Solana-Specific Vulnerability Analysis

| Vulnerability Pattern | Status | Notes |
|---|---|---|
| **Arbitrary CPI** | **SECURE** | All program IDs validated via `address` constraints or `Program<'info, T>` types |
| **Improper PDA Validation** | **SECURE** | All PDAs use canonical bumps via Anchor `seeds`/`bump` constraints |
| **Missing Signer Checks** | **SECURE** | All privileged operations require `Signer<'info>` with address constraints |
| **Missing Ownership Checks** | **MEDIUM RISK** | `stake_pool` has no owner check; mitigated by downstream SPL validation |
| **Sysvar Spoofing** | **SECURE** | All sysvars use Anchor's `Sysvar<'info, T>` wrappers |
| **Instruction Introspection** | **N/A** | Not used in this program |
| **Account Reinitialization** | **SECURE** | `init` prevents re-init; `init_if_needed` has proper guards |

---

## Architecture & Trust Boundary Analysis

### System Architecture

```
User (allowlisted) → LC Program (ACL gate) → SPL Stake Pool → Native Stake Program
     SOL/Stake in  →  allowlist + pause    →  Pool tokens   → Validator delegation
     Pool tokens   →  allowlist + pause    →  SOL/Stake out ← Validator undelegation
```

### Trust Boundaries

1. **Program ↔ Deployer**: `initialize` has no access control (anyone can deploy instances). State is a keypair, not a fixed PDA.
2. **Program ↔ SPL Stake Pool**: `funding_authority` PDA bridges the trust boundary. SPL program validates authority during CPI.
3. **Admin ↔ Pauser**: Asymmetric by design. Pauser can halt; only admin can resume.

### Key Architectural Risks

- **No timelock** on any privileged operation (admin changes, role changes take effect immediately)
- **No on-chain multisig enforcement** — admin/pauser/allower are single pubkeys; multisig is an off-chain operational choice
- **No emergency withdrawal path** for users removed from allowlist while holding tokens
- **Forked SPL Stake Pool** (`spl-stake-pool v2.0.0-lc`) requires manual patching for upstream security fixes

### Role Hierarchy

```
admin (highest privilege)
  ├── unpause
  ├── set_admin (requires new_admin co-sign)
  ├── set_pauser (unilateral)
  └── set_allower (unilateral)

pauser
  └── pause (one-way; cannot unpause)

allower
  ├── add_to_allowlist_entry
  └── remove_from_allowlist_entry

initial_manager (one-time use)
  ├── create_pool
  └── freeze authority on pool_mint

allowlisted users
  ├── deposit_sol
  ├── deposit_stake
  ├── withdraw_sol
  └── withdraw_stake
```

---

## Supply Chain Risk Assessment

| Dependency | Risk Level | Notes |
|---|---|---|
| `spl-stake-pool` (git fork) | **HIGH** | Private fork at `github.com/liquid-collective/solana-program-library#spl-stake-pool-v2.0.0-lc`; 1 GitHub star; critical staking logic; manual security patch responsibility |
| `anchor-lang` 0.32.1 | **Low** | Organization-backed (Coral), actively maintained, 2.8k stars |
| `anchor-spl` 0.32.1 | **Low** | Matches anchor-lang version |
| `solana-program` 2.x | **Low** | Core Solana SDK, maintained by Solana Labs |
| `borsh` 1.5.7 | **Low** | Widely used serialization library (Near Protocol), 320 stars |
| `bincode` 1.3.1 | **Medium** | Upstream repo archived August 2025; test-only dependency |

### Key Supply Chain Concerns

1. **Forked SPL Stake Pool** is the highest risk. The program depends on a private fork with minimal community oversight. Security patches from upstream SPL must be manually merged.

2. **Missing Security Policies**: 7 of 8 unique dependency repositories lack a formal `SECURITY.md` or security vulnerability reporting policy.

3. **Bincode Archived**: While only used in tests, the archival of bincode upstream indicates the maintainer has moved on. Consider migrating test serialization.

### Recommendations

- Establish a documented process for monitoring and merging upstream SPL Stake Pool security patches
- Consider upstreaming Liquid Collective changes to the official SPL repository
- Set up Dependabot or similar tooling to monitor dependency updates
- Migrate away from bincode for test fixtures

---

## Actionable Recommendations (Priority Order)

### Priority 1: Address Before/At Deployment

| Priority | Item | Effort | Finding |
|---|---|---|---|
| P1 | Store `stake_pool` key in `State` and validate in all instructions | Low | #1 |
| P1 | Make slippage parameters required (non-optional) | Low | #3 |
| P1 | Add `.gitignore` entry for `wallets/localnet/` and audit key reuse | Trivial | #2 |
| P1 | Add `Pubkey::default()` check to `set_admin` | Trivial | #4 |
| P1 | Replace `.unwrap()` with proper error handling in `deposit_stake.rs:80` | Low | #11 |
| P1 | Remove dead `only_staker` function | Trivial | #10 |
| P1 | Add `numerator <= denominator` fee validation | Trivial | #6 |

### Priority 2: Address for Production Quality

| Priority | Item | Effort | Finding |
|---|---|---|---|
| P2 | Evaluate whether `recipient` should be allowlist-constrained | Medium | #5 |
| P2 | Add owner/PDA constraints to `stake_pool_withdraw_authority` | Low | #12 |
| P2 | Consider `close` mechanism for allowlist entries (rent reclaim) | Medium | #7 |
| P2 | Require co-signature for `set_pauser`/`set_allower` | Low | #8 |
| P2 | Add fuzzing/property-based tests (Trident, proptest) | Medium | Testing gaps |
| P2 | Document architecture, invariants, and threat model | Medium | Documentation gaps |
| P2 | Establish process for syncing forked `spl-stake-pool` | Ongoing | Supply chain |

### Priority 3: Nice to Have

| Priority | Item | Effort | Finding |
|---|---|---|---|
| P3 | Initialize program in paused state | Low | #9 |
| P3 | Add min amount validation (> 0) | Trivial | #14 |
| P3 | Change Anchor.toml default cluster to localnet | Trivial | #15 |
| P3 | Resolve `#[allow(deprecated)]` suppressions | Low | #16 |
| P3 | Add `max_validators` range validation | Trivial | #17 |
| P3 | Remove pause constraint from `set_admin` (emergency recovery) | Low | #18 |
| P3 | Fix doc comment in lib.rs | Trivial | #19 |
| P3 | Add on-chain timelock for admin operations | High | Decentralization |
| P3 | Activate bug bounty program | Operational | Auditing practices |

---

## Methodology

### Agents and Skills

| Agent | Skill | What It Checked |
|---|---|---|
| Solana Vulnerability Scanner | building-secure-contracts:solana-vulnerability-scanner | 6 critical Solana vulnerability patterns (CPI, PDA, signer, owner, sysvar, reinitialization) |
| Audit Context Builder | audit-context-building:audit-context | Architecture, trust boundaries, privilege escalation paths, state management |
| Entry Point Analyzer | entry-point-analyzer:entry-points | All 13 state-changing entry points and access control flows |
| Code Maturity Assessor | building-secure-contracts:code-maturity-assessor | 9-category maturity framework (arithmetic, auditing, access controls, complexity, decentralization, documentation, MEV, low-level code, testing) |
| Guidelines Advisor | building-secure-contracts:guidelines-advisor | Best practices, architecture patterns, testing coverage, dependency management |
| Insecure Defaults Scanner | insecure-defaults:insecure-defaults | Fail-open patterns, optional safety checks, hardcoded secrets, dangerous defaults |
| Sharp Edges Analyzer | sharp-edges:sharp-edges | Footgun APIs, dangerous configurations, subtle bugs, edge cases |
| Supply Chain Risk Auditor | supply-chain-risk-auditor:supply-chain-risk-auditor | Dependency health, takeover risk, security policies, maintenance status |
| Zeroize Audit | zeroize-audit:zeroize-audit | Sensitive data zeroization in memory, secret key handling |

### Cross-Reference Process

This audit was performed in single-pass mode without cross-referencing. Each agent produced findings independently, which were then merged and deduplicated in this report.

In a full cross-reference audit, each agent would receive the findings from all other agents and produce AGREE/DISAGREE/NUANCE verdicts with written justification. Findings with DISAGREE verdicts would be flagged as "Disputed" in the report. Confidence would be adjusted: -10 per DISAGREE verdict (minimum 10). Findings where all 3 reviewers DISAGREE would be moved to an appendix.

### Limitations

- AI analysis cannot verify the complete absence of vulnerabilities.
- No formal verification of cryptographic implementations was performed.
- The audit was performed on source code only; no on-chain deployment was analyzed.
- Fork-based integration testing was not performed.
- No manual expert audit was performed; this is an automated multi-agent analysis.
- Findings should be reviewed by the development team and prioritized based on operational context.

---

> This review was performed by an AI-assisted multi-agent audit. AI analysis can never verify the complete absence of vulnerabilities and no guarantee of security is given. Human expert reviews, additional audits, bug bounty programs, and on-chain monitoring are strongly recommended before mainnet deployment.
