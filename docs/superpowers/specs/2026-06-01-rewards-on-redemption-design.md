# Rewards on Redemption Design

## Status

Approved design baseline from brainstorming on 2026-06-01. This document covers the new redemption economics and oracle accounting. Migration of already-pending legacy redeem requests is out of scope.

## Goal

Redeemers should keep staking rewards until the ETH that backs their queued redemption stops earning. Once ETH becomes inactive, the protocol locks a redemption rate for the matched queued LsETH. A later claim pays the lower of the inactive locked rate and the actual withdrawal rate, so slashings can still reduce payout.

The previous request-time `maxRedeemableEth` cap is replaced for the new flow. It should not be combined with the inactive-event cap.

## Architecture

Add a FIFO `RateLockStack` to `RedeemManager`, parallel to the existing `WithdrawalStack`.

`River` remains the oracle-report coordinator:

- Accept two new cumulative oracle report fields:
  - `validatorsPartialExitWithdrawnBalance`
  - `validatorsStoppedEarningBalance`
- Compute per-report deltas from the previously stored report.
- Combine both deltas into one inactive ETH amount.
- Convert the inactive ETH amount at the previous completed report share price.
- Cap the converted LsETH coverage to current rate-lock demand.
- Report one combined rate-lock event to `RedeemManager`.

`RedeemManager` owns redemption matching:

- Redeem requests stay FIFO by LsETH height.
- Withdrawal events stay FIFO by LsETH height.
- Rate-lock events are FIFO by LsETH height.
- A claim requires both rate-lock coverage and actual withdrawal coverage.

Oracle reports must stay bounded and must not loop over queued redeem requests.

## Oracle Report Semantics

Add two cumulative monotonic fields to `IOracleManagerV1.ConsensusLayerReport` and `IOracleManagerV1.StoredConsensusLayerReport`:

```solidity
uint256 validatorsPartialExitWithdrawnBalance;
uint256 validatorsStoppedEarningBalance;
```

Field semantics:

- `validatorsPartialExitWithdrawnBalance`: cumulative partial-exit ETH that has become inactive and has been withdrawn to the execution layer.
- `validatorsStoppedEarningBalance`: cumulative full-exit ETH that has stopped earning at `exit_epoch`, even if it has not yet been swept.

Existing field semantic changes:

- `validatorsSkimmedBalance` excludes partial-exit ETH now represented in `validatorsPartialExitWithdrawnBalance`.
- `validatorsExitingBalance` includes ETH that stopped earning at `exit_epoch`, even before sweep.
- `validatorsExitedBalance` remains the cumulative swept full-exit ETH used to pull actual full-exit funds.

Report validation:

- Revert when `validatorsPartialExitWithdrawnBalance` decreases.
- Revert when `validatorsStoppedEarningBalance` decreases.

CL fund routing:

```text
skimmedDelta -> BalanceToDeposit
exitedDelta -> BalanceToRedeem
partialExitDelta -> BalanceToRedeem
stoppedEarningDelta -> no pull; rate-lock only
```

Partial-exit ETH is pulled separately and routed to `BalanceToRedeem`. If it exceeds redeem needs, the existing `_skimExcessBalanceToRedeem()` path moves the excess to `BalanceToDeposit`.

Stopped-earning full-exit ETH creates rate-lock coverage when it stops earning, but actual ETH is pulled later when the sweep appears in `validatorsExitedBalance`.

## Share Price Locking

Store the previous completed report share price with the stored report.

Conceptually:

```text
lastSharePrice = totalUnderlyingSupply * 1e18 / totalSupply
```

At oracle report N, inactive ETH is converted using the stored share price from report N-1.

Report flow:

1. Load `lastSharePrice` from the previous completed report.
2. Compute:

   ```text
   inactiveEthDelta = partialExitDelta + stoppedEarningDelta
   ```

3. Convert with floor rounding:

   ```text
   lockLsEth = inactiveEthDelta * 1e18 / lastSharePrice
   ```

4. Cap lock coverage to current rate-lock demand.
5. Report one rate-lock event to `RedeemManager`.
6. After report accounting completes, compute and store the new share price for the next report.

If `totalSupply == 0` or `lastSharePrice == 0`, no lock event is created.

## RedeemManager Data Model

Add a new storage library:

```solidity
library RateLockStack {
    struct RateLockEvent {
        uint256 amount;    // LsETH coverage
        uint256 ethAmount; // ETH value locked for that LsETH coverage
        uint256 height;    // cumulative LsETH height
    }
}
```

Add `RateLockDemand` state:

- Increment when a redeem request is created.
- Decrement when rate-lock coverage is reported.
- Do not change when withdrawals are reported.
- Do not change during claims.

`redeemDemand` keeps its current meaning: LsETH still waiting for actual withdrawal ETH.

Add a River-only report function on `RedeemManager`, conceptually:

```solidity
function reportInactiveEth(uint256 lsEthAmount, uint256 ethAmount) external;
```

Rules:

- If `lsEthAmount == 0`, do nothing.
- Compute effective coverage:

  ```text
  effectiveLsEth = min(lsEthAmount, rateLockDemand)
  effectiveEth = ethAmount * effectiveLsEth / lsEthAmount
  ```

- If `effectiveLsEth == 0`, do nothing.
- Append one `RateLockEvent` with `effectiveLsEth` and `effectiveEth`.
- Event height is previous lock event `height + amount`, or zero for the first event.
- Decrease `rateLockDemand` by `effectiveLsEth`.
- Do not revert when reported inactive ETH exceeds rate-lock demand. Excess inactive ETH is ignored for redemption locks so unsolicited exits do not block oracle reporting.

For new redeem requests:

- `redeemDemand` increases by the requested LsETH amount.
- `rateLockDemand` increases by the requested LsETH amount.
- The request-time `maxRedeemableEth` field is not part of the new economic cap. If the field remains in storage for compatibility, new-flow claims ignore it and use rate-lock events instead.
- Add `rateLockHeight` to each new-flow redeem request. It starts at the same value as `height` and advances with successful claims, but it is resolved against `RateLockStack`.

## Claim Matching

Claims resolve a redeem request against two FIFO stacks:

- `RateLockStack`: the queued LsETH range has stopped earning and has a locked ETH cap.
- `WithdrawalStack`: actual ETH is available.

A request is claimable only for the overlapping LsETH range covered by both stacks.

For each matched segment:

```text
lsEthMatched = min(
  request remaining,
  remaining amount in current rate-lock event,
  remaining amount in current withdrawal event
)

lockedEth = lsEthMatched * rateLockEvent.ethAmount / rateLockEvent.amount
withdrawalEth = lsEthMatched * withdrawalEvent.withdrawnEth / withdrawalEvent.amount

ethPaid = min(lockedEth, withdrawalEth)
excessEth = withdrawalEth - ethPaid
```

If `excessEth > 0`, send it to the existing `BufferedExceedingEth` path.

This preserves slashing behavior: if actual withdrawal ETH per LsETH is lower than the locked rate, the redeemer receives the lower realized amount.

When a claim succeeds:

- Advance the request withdrawal `height`.
- Advance the request `rateLockHeight`.
- Decrease request `amount` by `lsEthMatched`.
- Keep withdrawal and rate-lock events immutable. Remaining event capacity is inferred from the updated request pointers and the event boundaries.

## Resolution And Claim APIs

Keep the existing claim API shape. Claim calldata must not include rate-lock event IDs:

```solidity
claimRedeemRequests(uint32[] redeemRequestIds, uint32[] withdrawalEventIds, ...)
```

Callers continue to supply withdrawal event IDs only. `RedeemManager` resolves the matching rate-lock event internally from the request's `rateLockHeight`.

Internal claim flow:

1. Load the redeem request.
2. Validate the caller-supplied withdrawal event against the request's withdrawal `height`.
3. Resolve the rate-lock event from the request's `rateLockHeight`.
4. Claim the overlap across the redeem request, withdrawal event, and internally resolved rate-lock event.
5. If the claim crosses a rate-lock boundary, advance to the next rate-lock event internally.

Rate-lock event IDs are an implementation detail. They are not required from callers and are not trusted as claim input.

Add a richer resolver for off-chain clients:

```solidity
function resolveRedeemRequestsV2(uint32[] calldata redeemRequestIds)
    external
    view
    returns (int64[] memory rateLockEventIds, int64[] memory withdrawalEventIds);
```

Rules:

- If either side is missing, the request is unsatisfied.
- Existing `resolveRedeemRequests` continues returning withdrawal event IDs only for backward compatibility.
- New clients should use `resolveRedeemRequestsV2` for visibility into both coverage streams.
- Claim reverts if the supplied withdrawal event matches but no matching rate-lock event exists.
- Claim does not accept, validate, or trust rate-lock event IDs in calldata.

## Testing

RedeemManager unit tests:

- `reportInactiveEth` appends one rate-lock event.
- `reportInactiveEth` caps to `rateLockDemand`.
- `reportInactiveEth` does nothing when `rateLockDemand == 0`.
- `reportInactiveEth` does not revert on unsolicited inactive ETH.
- Claims require both rate-lock and withdrawal coverage.
- Claims do not require rate-lock event IDs in calldata.
- Claims split correctly across multiple rate-lock and withdrawal boundaries.
- Slashing claims pay `min(locked rate, withdrawal rate)`.
- Excess ETH is buffered only when withdrawal ETH is higher than locked ETH.

River oracle-report tests:

- New cumulative fields reject decreases.
- Partial-exit delta is pulled and routed to `BalanceToRedeem`.
- Stopped-earning delta creates lock coverage but does not pull funds.
- `validatorsSkimmedBalance` excludes partial exits.
- `validatorsExitingBalance` accepts stopped-earning ETH before sweep.
- `lastSharePrice` is stored after each completed report and used by the next report.

Integration and accounting scenarios:

- Partial exit funds a redeem and locks the previous report rate in the same report.
- Full exit locks at `exit_epoch`, and claim waits until sweep creates a withdrawal event.
- Unsolicited inactive ETH with no redeem demand does not block reporting and does not create future lock capacity.
- Excess `BalanceToRedeem` still skims back to `BalanceToDeposit`.

Invariants:

- No redeem request can be paid without both rate-lock and withdrawal coverage.
- Cumulative rate-lock LsETH amount never exceeds cumulative new-flow requested LsETH.
- `redeemDemand` and `rateLockDemand` cannot underflow and only decrease through their respective report events.
- Total ETH paid plus buffered excess never exceeds actual ETH supplied to `RedeemManager`.

## Out Of Scope

- Migration strategy for already-pending legacy redeem requests.
- Backend implementation details for detecting inactive ETH.
- UI changes.
