---
shaping: true
---

# A3 Spike: Consolidation Entry Point

## Context

We need a `consolidate()` entry point on River that:
- Allows an external validator to consolidate into an LC validator
- Records the expected consolidation amount so it can be reconciled in the oracle report
- Mints LsETH at the correct conversion rate
- Is gated by the allowlist

The key constraint from the buffer reconciliation spike: **when minting happens, the expected consolidation amount must be atomically recorded in `PendingConsolidationBalance`** so that `_assetBalance()` immediately reflects the incoming ETH and the conversion rate is correct.

## Goal

Determine the concrete mechanics of the consolidation entry point: who calls what, when minting happens, what data is stored, and how the oracle interacts.

## Questions

| # | Question | Answer |
|---|----------|--------|
| **Q1** | How does a consolidation request reach the CL? What EL contract is involved? | EIP-7251 introduces a system contract at a predefined address (the consolidation request contract). To request a consolidation, an EL transaction is sent to this contract with `source_pubkey ++ target_pubkey` (96 bytes). The request must come from the source validator's withdrawal credentials address. On CL, the request is processed: if valid, the source validator's `exit_epoch` is set, and eventually its balance transfers to the target. |
| **Q2** | Who can initiate a consolidation into LC? | The **owner of the source validator** (the address set as the source validator's withdrawal credentials). They must be allowlisted on LC. They call River, which then submits the consolidation request to the CL system contract. **River must be the one calling the system contract**, because consolidation requests can also be triggered by the withdrawal credentials address of the source — but for LC the target validator's withdrawal credentials point to the Withdraw contract, so the request routing matters. |
| **Q3** | When does LsETH get minted — at consolidation request time or at CL acceptance? | **At consolidation request time (same tx as the EL call).** Rationale: (1) The user expects immediate LsETH, similar to `deposit()` which mints immediately. (2) The consolidation amount is known at request time (user provides it, keyed to their source validator's CL balance). (3) `PendingConsolidationBalance` is incremented in the same tx, so `_assetBalance()` is immediately correct. (4) Waiting for oracle introduces delay and complexity. The risk (user provides wrong amount) is handled by oracle reconciliation + insolvency protection (A8). |
| **Q4** | What if the user lies about the expected consolidation amount? | **Two protections:** (1) The oracle reconciliation (A4) will detect the mismatch — `validatorsConsolidatedBalance` delta won't match `PendingConsolidationBalance`. The buffer will remain partially inflated, which dilutes the conversion rate for all holders. (2) Insolvency protection (A8) handles the writedown. **Mitigation at entry:** The keeper/oracle could provide the expected balance as a signed attestation, or the consolidation could require a two-step process where the oracle confirms the source validator's balance before minting. See alternatives below. |
| **Q5** | What data needs to be stored per consolidation request? | A `ConsolidationRequest` struct for each pending consolidation. Needed for: (a) oracle to match CL events to pending requests, (b) reconciliation to know which requests completed/failed, (c) insolvency protection to know what to write down. |
| **Q6** | How does this interact with `_assetBalance()` during the oracle report? | At request time: `PendingConsolidationBalance += expectedAmount` → `_assetBalance()` goes up → LsETH minted at correct rate. At oracle reconciliation: `PendingConsolidationBalance -= consolidatedDelta` and `validatorsBalance` increases by same delta → `_assetBalance()` net change = 0 for the consolidation portion. See [spike-buffer-reconciliation.md](spike-buffer-reconciliation.md). |
| **Q7** | Does the source validator need to change its withdrawal credentials to LC's Withdraw contract first? | **No.** In EIP-7251 consolidation, the source validator is consumed (exits). Its balance is transferred to the target validator on the CL. The source validator's withdrawal credentials are irrelevant after the transfer — the funds end up under the target validator, which already has LC's withdrawal credentials. The source just needs to sign the consolidation request (or have its withdrawal credentials address initiate it from EL). |

## Consolidation Entry Point Alternatives

### A3-A: User-initiated, immediate mint (single tx)

```
User calls: River.consolidate(sourcePubkey, targetPubkey, expectedBalance)

1. Allowlist check: onlyAllowed(msg.sender, CONSOLIDATION_MASK)
2. Validate: targetPubkey belongs to an LC operator (check OperatorsRegistry)
3. Record: ConsolidationRequests.push({
     sourcePubkey, targetPubkey, recipient: msg.sender,
     expectedBalance, status: PENDING, requestEpoch: currentEpoch
   })
4. Buffer: PendingConsolidationBalance += expectedBalance
5. Mint: _mintShares(msg.sender, expectedBalance)  // uses current conversion rate
6. Submit: Call CL consolidation request system contract with source ++ target
7. Emit: ConsolidationRequested(requestId, msg.sender, sourcePubkey, targetPubkey, expectedBalance)
```

**Pros:** Simple UX (one tx), immediate LsETH, mirrors `deposit()` pattern.
**Cons:** User provides `expectedBalance` — could be wrong or malicious. Relies on oracle reconciliation + A8 for safety.

### A3-B: Keeper-attested, immediate mint (two tx)

```
Step 1 — User calls: River.requestConsolidation(sourcePubkey, targetPubkey)
  1. Allowlist check
  2. Record: ConsolidationRequests.push({
       sourcePubkey, targetPubkey, recipient: msg.sender,
       expectedBalance: 0, status: REQUESTED
     })
  3. Emit: ConsolidationRequested(requestId, msg.sender, sourcePubkey, targetPubkey)

Step 2 — Keeper calls: River.executeConsolidation(requestId, expectedBalance, keeperSig?)
  1. Only keeper
  2. Validate: keeper confirms source validator balance from CL data
  3. Update: request.expectedBalance = expectedBalance, status = PENDING
  4. Buffer: PendingConsolidationBalance += expectedBalance
  5. Mint: _mintShares(request.recipient, expectedBalance)
  6. Submit: Call CL consolidation request system contract
  7. Emit: ConsolidationExecuted(requestId, expectedBalance)
```

**Pros:** Keeper verifies CL balance before minting — much safer. No trust in user-provided amount.
**Cons:** Two tx, user waits for keeper. Keeper becomes a bottleneck/trust point (but already trusted for deposits via BYOV).

### A3-C: Oracle-confirmed mint (two tx, delayed)

```
Step 1 — User calls: River.requestConsolidation(sourcePubkey, targetPubkey)
  1. Allowlist check
  2. Record request
  3. Submit CL consolidation request immediately

Step 2 — Oracle reports CL acceptance in next report:
  Oracle includes: confirmedConsolidations[] = [{requestId, confirmedBalance}]
  River in setConsensusLayerData:
  1. For each confirmed consolidation:
     - PendingConsolidationBalance += confirmedBalance
     - _mintShares(request.recipient, confirmedBalance)
     - request.status = ACCEPTED
```

**Pros:** Oracle provides authoritative CL balance. No trust in user or keeper for the amount.
**Cons:** Delayed minting (waits for next oracle report — could be hours). Minting inside oracle report adds complexity and gas. Complex oracle report structure.

## Concrete Data Structures

### ConsolidationRequest storage

```solidity
struct ConsolidationRequest {
    bytes32 sourcePubkeyHash;   // keccak256 of source pubkey (for lookup)
    bytes32 targetPubkeyHash;   // keccak256 of target pubkey
    address recipient;          // LsETH recipient
    uint256 expectedBalance;    // ETH expected from consolidation
    uint256 reconciledBalance;  // ETH actually reconciled by oracle (0 until reconciled)
    uint64 requestTimestamp;    // when initiated
    uint8 status;               // REQUESTED(0), PENDING(1), COMPLETED(2), FAILED(3)
}
```

### Storage: ConsolidationRequests array + mapping

```solidity
// Array of all consolidation requests (append-only)
ConsolidationRequest[] consolidationRequests;

// Map sourcePubkeyHash → requestId for oracle lookup
mapping(bytes32 => uint256) consolidationRequestBySource;
```

### New Allowlist mask

```solidity
uint256 internal constant CONSOLIDATION_MASK = 0x8;  // bit 4
```

## Recommendation

**A3-B (Keeper-attested)** is the best fit because:

1. **Consistent with BYOV pattern** — the keeper is already trusted for validator allocation decisions. Adding consolidation attestation is a natural extension.
2. **No user trust for amounts** — the keeper reads CL state and provides the correct expected balance.
3. **Immediate-ish minting** — user waits for keeper (seconds to minutes), not for oracle report (hours).
4. **Clean separation** — user expresses intent (step 1), keeper validates and executes (step 2).
5. **`PendingConsolidationBalance` and minting are atomic in step 2** — the amount recorded in the buffer is exactly the amount used for minting, and it's provided by a trusted party.

The keeper already has CL visibility (it does BYOV allocation). Adding "read source validator balance" is trivial.

## Acceptance

Spike is complete when we can describe the consolidation entry point flow, data structures, and how the expected amount gets recorded atomically with minting.

**✅ Complete** — A3-B (keeper-attested two-step) is the recommended approach. The expected consolidation amount is recorded by the keeper (who reads CL state) at execution time, atomically with LsETH minting and `PendingConsolidationBalance` increment. Oracle reconciles later via `validatorsConsolidatedBalance` delta.
