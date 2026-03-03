---
shaping: true
---

# A6/A7 Spike: Partial Exits + Keeper Exit Strategy

## Context

Currently, the only way to satisfy redemption demand that exceeds available ETH buffers is full validator exits (32 ETH each, ~27 hour exit queue). EIP-7002 introduces EL-triggered withdrawal requests, enabling partial withdrawals (withdraw some ETH from a validator without fully exiting it). This spike investigates the concrete mechanics of integrating partial exits into the existing exit flow and the keeper's decision-making strategy.

## Goal

Understand how EIP-7002 partial exits integrate with: (1) the existing exit demand / pre-exiting balance tracking, (2) the oracle reporting flow, (3) the Withdraw contract, and (4) how the keeper decides between partial and full exits.

## Questions

| # | Question | Answer |
|---|----------|--------|
| **Q1** | How does EIP-7002 work mechanically? | A system contract at a predefined address accepts withdrawal requests. Call it with `validator_pubkey (48 bytes) ++ amount (8 bytes, LE gwei)`. If `amount == 0` or `amount >= validator_balance` → full exit. If `amount < validator_balance` → partial withdrawal. The call must come from the validator's **withdrawal credentials address**. A dynamic fee (similar to EIP-1559) must be paid in ETH with the call. For LC validators, the withdrawal credentials address is the **Withdraw contract**. |
| **Q2** | Who calls the EIP-7002 system contract? | The **Withdraw contract** — because it IS the withdrawal credentials address for all LC validators. River calls Withdraw, Withdraw calls the system contract. This requires a new function on Withdraw: `requestWithdrawal(pubkey, amount)`, callable only by River. River exposes a keeper-callable function that routes through Withdraw. |
| **Q3** | How do partial exit funds arrive and get classified by the oracle? | Partial exit funds arrive at the Withdraw contract as CL withdrawals (same as skimming and full exits). The oracle can classify them via `validatorsExitedBalance` (cumulative, non-decreasing). This works because: (1) `_pullCLFunds` routes exited funds to `BalanceToRedeem` — correct for satisfying redemptions. (2) The decrease in `validatorsBalance` + increase in `validatorsExitedBalance` cancel out in `_assetBalance()` — bounds check sees only rewards. (3) Stopped validator counts are tracked separately and are unaffected. **No new oracle field needed for partial exits.** |
| **Q4** | How does partial exit tracking differ from full exit tracking? | Full exits are tracked by **validator count**: `CurrentValidatorExitsDemand`, `TotalValidatorExitsRequested`, `stoppedValidatorCountPerOperator`. Partial exits must be tracked by **ETH amount**: a new `PendingPartialExitBalance` variable (or similar) tracks how much ETH has been requested via partial exits but not yet received. This is used in the exit demand calculation to avoid over-requesting. |
| **Q5** | How does `preExitingBalance` change with partial exits? | Currently: `preExitingBalance = (requestedExits - stoppedValidators) * DEPOSIT_SIZE`. With partial exits, it becomes: `preExitingBalance = (requestedFullExits - stoppedValidators) * DEPOSIT_SIZE + PendingPartialExitBalance`. The partial exit amount is added directly (it's already in ETH), the full exit portion stays count-based at 32 ETH per validator. |
| **Q6** | How does the keeper decide between partial and full exits? | **Decision tree:** (1) Calculate shortfall: `redeemDemandInEth - (BalanceToRedeem + exitingBalance + preExitingBalance)`. (2) If shortfall <= available excess balance across validators → **partial exits only** (faster, cheaper, no validator loss). (3) If shortfall > available excess but can be partially covered → **partial exits + full exits** for the remainder. (4) If no excess balance → **full exits only**. The keeper needs CL visibility to know which validators have excess balance above 32 ETH. |
| **Q7** | What's the EIP-7002 fee model? Is it economically viable? | The fee uses an EIP-1559-like mechanism: starts low, increases exponentially with demand. In normal conditions the fee is negligible (< 1 gwei). It only becomes expensive under extreme network-wide exit demand. For LC's purposes, the fee is almost always trivially small and should not be a barrier. The fee is paid from River's ETH balance (or from Withdraw contract balance). |
| **Q8** | Can the keeper trigger both full exits and partial exits in the same call? | Ideally yes — for efficiency. A single keeper call could specify a mix of full and partial exits. The contract would loop through, calling the EIP-7002 system contract for each. |

## Concrete Mechanism

### 1. Withdraw contract upgrade

```solidity
// New function on WithdrawV1
// Calls the EIP-7002 withdrawal request system contract
function requestWithdrawal(
    bytes calldata _pubkey,     // 48 bytes
    uint64 _amountInGwei        // 0 = full exit, >0 = partial withdrawal amount in gwei
) external onlyRiver {
    // Encode: pubkey (48 bytes) ++ amount (8 bytes, little-endian)
    bytes memory request = abi.encodePacked(_pubkey, _toLittleEndian64(_amountInGwei));

    // Call EIP-7002 system contract (predefined address)
    // Fee is paid from Withdraw contract's ETH balance
    (bool success,) = WITHDRAWAL_REQUEST_CONTRACT.call{value: fee}(request);
    require(success);
}
```

### 2. River: keeper-callable partial exit function

```solidity
struct PartialExitRequest {
    bytes pubkey;          // 48 bytes - validator to partially exit
    uint64 amountInGwei;   // amount to withdraw in gwei
}

struct ExitRequest {
    PartialExitRequest[] partialExits;
    OperatorAllocation[] fullExits;      // existing pattern
}

// Keeper calls this to request a mix of partial and full exits
function requestExits(ExitRequest calldata _request) external onlyKeeper {
    uint256 totalPartialExitAmount = 0;

    // Process partial exits via Withdraw → EIP-7002 system contract
    for (uint256 i = 0; i < _request.partialExits.length; i++) {
        uint256 amount = uint256(_request.partialExits[i].amountInGwei) * 1 gwei;
        IWithdrawV1(WithdrawalCredentials.getAddress()).requestWithdrawal(
            _request.partialExits[i].pubkey,
            _request.partialExits[i].amountInGwei
        );
        totalPartialExitAmount += amount;
    }

    // Track pending partial exits
    PendingPartialExitBalance += totalPartialExitAmount;

    // Process full exits via existing OperatorsRegistry flow
    if (_request.fullExits.length > 0) {
        IOperatorsRegistryV1(OperatorsRegistryAddress.get())
            .requestValidatorExits(_request.fullExits);
    }
}
```

### 3. New storage variable

```solidity
// PendingPartialExitBalance — total ETH requested via partial exits, not yet received
// Incremented when keeper submits partial exit requests
// Decremented when oracle reconciles (partial exit funds arrive via validatorsExitedBalance)
```

### 4. Modified exit demand calculation (River._requestExitsBasedOnRedeemDemandAfterRebalancings)

```
CURRENT:
  preExitingBalance = (requestedExits - stoppedValidators) * 32 ETH
  shortfall = redeemDemandInEth - (BalanceToRedeem + exitingBalance + preExitingBalance)
  validatorCountToExit = ceil(shortfall / 32 ETH)
  → demandValidatorExits(validatorCountToExit)

NEW:
  preExitingFullBalance = (requestedExits - stoppedValidators) * 32 ETH
  preExitingBalance = preExitingFullBalance + PendingPartialExitBalance
  shortfall = redeemDemandInEth - (BalanceToRedeem + exitingBalance + preExitingBalance)

  // System still demands in validator counts for full exits
  // Keeper decides how to fill the demand (partial vs full)
  // The demandValidatorExits remains count-based
  // But the keeper has flexibility to use partial exits BEFORE demanding full exits
```

### 5. Oracle reconciliation of partial exits

```
Oracle reports:
  validatorsExitedBalance += partialExitAmount  (arrives as CL withdrawal)
  validatorsBalance -= partialExitAmount          (validator balance decreased)

In setConsensusLayerData:
  exitedAmountIncrease = new.validatorsExitedBalance - old.validatorsExitedBalance
  _pullCLFunds(skimmedIncrease, exitedAmountIncrease)
    → BalanceToRedeem += exitedAmountIncrease  (partial exit funds available for redemptions)

  // Reconcile PendingPartialExitBalance
  // The oracle needs to report how much of the exited balance is from partial exits
  // OR: we simply decrement PendingPartialExitBalance as funds arrive
  // Simplest: new oracle field validatorsPartiallyExitedBalance (cumulative)
  // Delta used to decrement PendingPartialExitBalance
```

**Wait — reconciliation subtlety:** We need to know which portion of `validatorsExitedBalance` increase is from partial exits vs full exits. Without this, we can't properly decrement `PendingPartialExitBalance`.

**Two options:**

**Option A: New oracle field `validatorsPartiallyExitedBalance`**
- Cumulative, non-decreasing (same pattern as skimmed/exited)
- Oracle distinguishes partial exit withdrawals from full exit withdrawals on CL
- Delta used to decrement `PendingPartialExitBalance`
- Clean, explicit

**Option B: Trust the keeper's accounting**
- Keeper tracks which partial exits have been submitted
- When `validatorsExitedBalance` increases, the keeper tells the system how much was partial
- Less robust — relies on keeper being correct

**Recommendation: Option A** — consistent with the pattern established in the buffer reconciliation spike. The oracle already distinguishes skimmed vs exited; adding partially-exited is a natural extension.

### 6. Keeper exit strategy (A7)

```
KEEPER DECISION LOGIC (off-chain):

Input:
  - redeemDemandInEth (from RedeemManager)
  - availableBalanceToRedeem (BalanceToRedeem)
  - exitingBalance (from oracle report)
  - preExitingBalance (pending full + partial exits)
  - validatorExcessBalances[] (from CL data: per-validator balance - 32 ETH)
  - EIP-7002 fee (from system contract)

Step 1: Calculate shortfall
  shortfall = redeemDemandInEth - (availableBalanceToRedeem + exitingBalance + preExitingBalance)
  if shortfall <= 0: DONE (no exits needed)

Step 2: Try partial exits first
  Sort validators by excess balance (descending)
  partialExitAmount = 0
  partialExitRequests = []
  for each validator with excess > 0:
    withdrawable = min(validator.excess, shortfall - partialExitAmount)
    if withdrawable > EIP_7002_FEE * MIN_FEE_RATIO:  // only if economically viable
      partialExitRequests.push({pubkey, withdrawable})
      partialExitAmount += withdrawable
    if partialExitAmount >= shortfall: BREAK

Step 3: If partial exits insufficient, add full exits
  remainingShortfall = shortfall - partialExitAmount
  if remainingShortfall > 0:
    fullExitCount = ceil(remainingShortfall / 32 ETH)
    fullExitAllocations = selectOperatorAllocations(fullExitCount)

Step 4: Submit combined request
  River.requestExits({partialExits, fullExits})
```

**Key insight:** The keeper prefers partial exits because:
- **Faster:** No exit queue wait (~minutes vs ~27 hours)
- **Cheaper:** No need to fund a new validator later
- **Preserves validator count:** Validator stays active, keeps earning rewards
- **Smaller unit:** Can exactly match redemption demand (no 32 ETH granularity)

**Fallback to full exits when:**
- No validators have excess balance (all at exactly 32 ETH)
- Partial exit fee is unreasonably high (extreme network demand)
- Redemption demand exceeds total available excess across all validators

### 7. Updated flow: Redeem demand → Exit → Completion

```
Phase 1: User requests redemption (UNCHANGED)
  → RedeemDemand increases

Phase 2: Oracle report triggers exit demand calculation
  → Modified to account for PendingPartialExitBalance in preExitingBalance
  → demandValidatorExits() may demand fewer full exits because partial exits cover some demand

Phase 3: Keeper decides strategy (NEW)
  → Reads CL state for validator excess balances
  → Calculates optimal mix of partial + full exits
  → Calls River.requestExits() with combined request
  → River routes partial exits through Withdraw → EIP-7002 system contract
  → River routes full exits through OperatorsRegistry (existing flow)

Phase 4: Partial exit funds arrive (NEW)
  → CL processes partial withdrawal → funds at Withdraw contract
  → Oracle reports validatorsPartiallyExitedBalance increase
  → River pulls funds → BalanceToRedeem += partialExitAmount
  → PendingPartialExitBalance -= partialExitAmount

Phase 5-7: (UNCHANGED)
  → reportWithdrawToRedeemManager, user claims
```

## Edge Cases

| Case | What happens |
|------|--------------|
| **Partial exit processed but less ETH arrives than requested** | `validatorsPartiallyExitedBalance` delta < requested. `PendingPartialExitBalance` remains partially inflated. Resolves on subsequent reports or via admin writedown. |
| **Validator slashed after partial exit request** | Partial exit may return less ETH. Handled same as above. |
| **EIP-7002 fee spikes during high demand** | Keeper checks fee before submitting. If fee > threshold, skips partial exits and falls back to full exits (which don't use EIP-7002 — operators do the CL exit voluntarily). |
| **Multiple partial exits on same validator** | Valid — a validator with 100 ETH excess could receive multiple partial exit requests. Keeper tracks cumulative requested amount per validator. |
| **Partial exit on validator that's also been requested for full exit** | The full exit takes precedence on CL. The partial exit amount should not be double-counted. Keeper should avoid this situation. |
| **No excess balance on any validators (all at 32 ETH)** | Partial exits impossible. Keeper falls back to full exits only. After Pectra + consolidations, validators will commonly have >32 ETH, making this less likely. |

## Conclusion

Partial exits via EIP-7002 slot cleanly into the existing architecture:
- **Call path:** Keeper → River → Withdraw → EIP-7002 system contract
- **Fund flow:** CL withdrawal → Withdraw contract → River (`_pullCLFunds`) → `BalanceToRedeem`
- **Tracking:** New `PendingPartialExitBalance` variable + oracle's `validatorsPartiallyExitedBalance` field
- **Demand calculation:** `preExitingBalance` now includes both full and partial pending exits
- **Keeper strategy:** Partial first (faster, cheaper), full exit as fallback

The keeper's role expands: in addition to BYOV deposit allocation and exit allocation, it now decides the optimal partial/full exit mix based on CL state.
