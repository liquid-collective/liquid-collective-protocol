/*
 * Stopped-Earning Rate Lock (SERL) — redemption rewards
 *
 * Covers the state and arithmetic introduced by the redemption-rewards work:
 *   RateMarkStack        — per-report slices of pending demand whose principal stopped earning
 *   RedeemRequestAnchor  — the immutable request-time valuation of a request
 *   RateMarkFloor        — the launch cutover, below which no mark may reach
 *   _sliceCap            — the payout ceiling, raised over marked sub-ranges
 *
 * Scope note: this spec runs against `RedeemManagerSERLHarness` ALONE. River and the Allowlist are
 * outside the scene and are summarised as NONDET, so every rule below holds for an ARBITRARY River —
 * arbitrary share rate, arbitrary allowlist verdicts, arbitrary transfer outcomes. That is strictly
 * stronger than pinning a River implementation, and it is what lets this conf run at all today:
 * `RiverV1Harness` does not compile (see certora/README.md), which is why the pre-existing
 * `RedeemManagerV1.conf` cannot be executed.
 *
 * Loop note: `_sliceCap` walks the mark stack and `_findRateMarkAtOrBefore` binary-searches it, both
 * unbounded. Under `loop_iter` N with `optimistic_loop`, results cover slices spanning at most N mark
 * boundaries. Raise `loop_iter` to widen that, at the usual cost.
 */

definition ignoredMethod(method f) returns bool =
    f.selector == sig:initializeRedeemManagerV1_2().selector
    || f.selector == sig:initializeRedeemManagerV1(address).selector;

/// A magnitude bound applied to symbolic LsETH/ETH quantities. `_sliceCap` multiplies an LsETH amount
/// by an ETH amount before dividing, so unbounded symbolic inputs make every rule vacuous on the
/// overflow path. 2^128 wei is ~3.4e20 ETH, far above total ETH supply.
definition REALISTIC(mathint x) returns bool = x >= 0 && x < 2^128;

methods {
    // ---- production views -----------------------------------------------------------------------
    function getRiver() external returns (address) envfree;
    function getRedeemRequestCount() external returns (uint256) envfree;
    function getRedeemRequestDetails(uint32) external returns (RedeemQueueV2.RedeemRequest) envfree;
    function getWithdrawalEventCount() external returns (uint256) envfree;
    function getRateMarkCount() external returns (uint256) envfree;
    function getRateMarkFloor() external returns (uint256) envfree;
    function getBufferedExceedingEth() external returns (uint256) envfree;
    function getRedeemDemand() external returns (uint256) envfree;

    // ---- harness views --------------------------------------------------------------------------
    function getRateMarkHeight(uint32) external returns (uint256) envfree;
    function getRateMarkAmount(uint32) external returns (uint256) envfree;
    function getRateMarkEth(uint32) external returns (uint256) envfree;
    function rateMarkCursor() external returns (uint256) envfree;
    function settledHeight() external returns (uint256) envfree;
    function totalRequestedHeight() external returns (uint256) envfree;
    function rateMarkFoundAtOrBefore(uint256) external returns (bool) envfree;
    function rateMarkIndexAtOrBefore(uint256) external returns (uint256) envfree;
    function getAnchorLsETH(uint32) external returns (uint256) envfree;
    function getAnchorEth(uint32) external returns (uint256) envfree;
    function sliceCap(uint256,uint256,uint256,uint256) external returns (uint256) envfree;
    function capForRequestSlice(uint32,uint256) external returns (uint256) envfree;
    function getRedeemRequestHeight(uint32) external returns (uint256) envfree;
    function getRedeemRequestAmount(uint32) external returns (uint256) envfree;
    function getRedeemRequestMaxRedeemableEth(uint32) external returns (uint256) envfree;
    function getWithdrawalEventHeight(uint32) external returns (uint256) envfree;
    function getWithdrawalEventAmount(uint32) external returns (uint256) envfree;
    function getWithdrawalEventWithdrawnEth(uint32) external returns (uint256) envfree;
    function get_CLAIM_FULLY_CLAIMED() external returns (uint8) envfree;
    function get_CLAIM_PARTIALLY_CLAIMED() external returns (uint8) envfree;
    function get_CLAIM_SKIPPED() external returns (uint8) envfree;

    // ---- River / Allowlist live outside the scene -------------------------------------------------
    function _.getAllowlist() external => NONDET;
    function _.onlyAllowed(address,uint256) external => NONDET;
    function _.isDenied(address) external => NONDET;
    function _.getSlashingContainmentMode() external => NONDET;
    function _.transferFrom(address,address,uint256) external => NONDET;
    function _.underlyingBalanceFromShares(uint256) external => NONDET;
    function _.sendRedeemManagerExceedingFunds() external => NONDET;
}

/*
 * =================================================================================================
 * 1. Mark placement — reportStoppedEarning
 * =================================================================================================
 */

/// A report appends at most one mark, and never removes one.
rule reportStoppedEarning_appends_at_most_one_mark(uint256 ethLeg, uint256 lsLeg) {
    env e;
    require e.msg.sender == getRiver();

    mathint countBefore = to_mathint(getRateMarkCount());
    reportStoppedEarning(e, ethLeg, lsLeg);
    mathint countAfter = to_mathint(getRateMarkCount());

    assert countAfter == countBefore || countAfter == countBefore + 1;
}

/// The mark a report appends starts at or above every lower bound the design imposes: the end of the
/// previous mark (so marks never overlap and heights stay strictly ascending, which is what
/// `_findRateMarkAtOrBefore`'s binary search assumes), the settled height (so already-priced demand is
/// never re-credited), and the launch cutover floor (so pre-upgrade requests cannot consume credit
/// owed to the first post-upgrade cohort).
rule reportStoppedEarning_mark_respects_all_floors(uint256 ethLeg, uint256 lsLeg) {
    env e;
    require e.msg.sender == getRiver();

    mathint countBefore = to_mathint(getRateMarkCount());
    require countBefore < 2^32;                       // rateMarkId is a uint32 cast
    mathint cursorBefore = to_mathint(rateMarkCursor());
    mathint settledBefore = to_mathint(settledHeight());
    mathint floorBefore = to_mathint(getRateMarkFloor());

    reportStoppedEarning(e, ethLeg, lsLeg);

    mathint countAfter = to_mathint(getRateMarkCount());
    uint32 newId = require_uint32(countAfter - 1);

    assert countAfter == countBefore + 1 => to_mathint(getRateMarkHeight(newId)) >= cursorBefore;
    assert countAfter == countBefore + 1 => to_mathint(getRateMarkHeight(newId)) >= settledBefore;
    assert countAfter == countBefore + 1 => to_mathint(getRateMarkHeight(newId)) >= floorBefore;
    // an empty mark would break strict ascension of heights, which the binary search relies on
    assert countAfter == countBefore + 1 => getRateMarkAmount(newId) > 0;
}

/// A mark never reaches past the end of the redeem queue: stopped-earning credit is only ever applied
/// to demand that has actually been requested.
rule reportStoppedEarning_mark_within_requested_demand(uint256 ethLeg, uint256 lsLeg) {
    env e;
    require e.msg.sender == getRiver();

    mathint countBefore = to_mathint(getRateMarkCount());
    require countBefore < 2^32;
    mathint totalRequested = to_mathint(totalRequestedHeight());

    reportStoppedEarning(e, ethLeg, lsLeg);

    mathint countAfter = to_mathint(getRateMarkCount());
    uint32 newId = require_uint32(countAfter - 1);

    assert countAfter == countBefore + 1 =>
        to_mathint(getRateMarkHeight(newId)) + to_mathint(getRateMarkAmount(newId)) <= totalRequested;
}

/// The clamp cannot inflate the locked rate. When `lsETHToMark` is cut down to the markable window,
/// the ETH leg is scaled down in the same proportion, so the marked rate stays at or below the rate
/// River reported. If this failed, a clamped report would hand redeemers ETH at a better rate than
/// the pool ever held.
rule reportStoppedEarning_locked_rate_not_above_reported(uint256 ethLeg, uint256 lsLeg) {
    env e;
    require e.msg.sender == getRiver();
    require REALISTIC(to_mathint(ethLeg)) && REALISTIC(to_mathint(lsLeg));

    mathint countBefore = to_mathint(getRateMarkCount());
    require countBefore < 2^32;

    reportStoppedEarning(e, ethLeg, lsLeg);

    mathint countAfter = to_mathint(getRateMarkCount());
    uint32 newId = require_uint32(countAfter - 1);
    mathint markAmount = to_mathint(getRateMarkAmount(newId));
    mathint markedEth = to_mathint(getRateMarkEth(newId));

    // markedEth / markAmount  <=  ethLeg / lsLeg, cross-multiplied to stay exact
    assert countAfter == countBefore + 1 => markedEth * to_mathint(lsLeg) <= to_mathint(ethLeg) * markAmount;
}

/// The mark cursor never runs past the redeem queue. This is the aggregate form of
/// `reportStoppedEarning_mark_within_requested_demand`: total marked LsETH can never exceed total
/// requested LsETH, so stopped-earning credit cannot be issued twice for the same demand.
invariant markCursorWithinRequestedDemand()
    to_mathint(rateMarkCursor()) <= to_mathint(totalRequestedHeight())
    filtered { f -> !ignoredMethod(f) }

/*
 * =================================================================================================
 * 2. Cutover — the anchor and the floor
 * =================================================================================================
 */

/// Once a request has an anchor it is frozen for the request's whole life. The entire cap computation
/// is priced off this pair, and `maxRedeemableEth` was rejected for the role precisely because it
/// drifts after a partial claim — so a mutable anchor would reintroduce the bug it exists to avoid.
rule anchor_is_immutable(method f, uint32 id)
    filtered { f -> !f.isView && !ignoredMethod(f) }
{
    require to_mathint(id) < to_mathint(getRedeemRequestCount());   // pins `id` to an existing request,
                                                                    // so requestRedeem's write at the new
                                                                    // tail id is not in scope here
    uint256 lsBefore = getAnchorLsETH(id);
    uint256 ethBefore = getAnchorEth(id);
    require lsBefore != 0;                                          // anchor already set

    env e; calldataarg args;
    f(e, args);

    assert getAnchorLsETH(id) == lsBefore;
    assert getAnchorEth(id) == ethBefore;
}

/// A newly opened request is anchored, and anchored at exactly the amount requested. A zero LsETH leg
/// is the pre-upgrade sentinel, so an anchor that failed to write would silently downgrade a live
/// request to legacy pricing.
rule requestRedeem_sets_anchor(uint256 lsETHAmount, address recipient) {
    env e;
    require to_mathint(getRedeemRequestCount()) < 2^32;             // redeemRequestId is a uint32 cast

    uint32 id = requestRedeem(e, lsETHAmount, recipient);

    assert getAnchorLsETH(id) == lsETHAmount;
    assert getAnchorLsETH(id) != 0;
    assert getAnchorEth(id) == getRedeemRequestMaxRedeemableEth(id);
}

/// The launch cutover is written once, by its own initializer, and by nothing else. A later write
/// would either strand credit above the new floor or let marks reach back over pre-upgrade requests.
rule rate_mark_floor_is_set_once(method f)
    filtered { f -> !f.isView && f.selector != sig:initializeRedeemManagerV1_3().selector && !ignoredMethod(f) }
{
    uint256 floorBefore = getRateMarkFloor();
    env e; calldataarg args;
    f(e, args);
    assert getRateMarkFloor() == floorBefore;
}

/// The cutover is pinned at the end of the queue as it stands at upgrade time, i.e. every request that
/// exists when V1_3 runs sits entirely below the floor and can never be marked.
rule initializeV1_3_pins_floor_at_queue_end() {
    env e;
    mathint queueEnd = to_mathint(totalRequestedHeight());
    initializeRedeemManagerV1_3(e);
    assert to_mathint(getRateMarkFloor()) == queueEnd;
}

/// A pre-upgrade request keeps the original pricing rule exactly: its cap is the pro-rata share of the
/// remaining request-time ETH budget, with no reference to any mark. This is the operative form of
/// "no retroactive application" — it holds no matter how the mark stack has since grown.
rule legacy_request_ignores_marks(uint32 id, uint256 matchingAmount) {
    require to_mathint(id) < to_mathint(getRedeemRequestCount());
    require getAnchorLsETH(id) == 0;                                 // predates the upgrade
    mathint amount = to_mathint(getRedeemRequestAmount(id));
    require amount > 0;
    require REALISTIC(to_mathint(matchingAmount));
    require REALISTIC(to_mathint(getRedeemRequestMaxRedeemableEth(id)));

    assert to_mathint(capForRequestSlice(id, matchingAmount))
        == (to_mathint(matchingAmount) * to_mathint(getRedeemRequestMaxRedeemableEth(id))) / amount;
}

/*
 * =================================================================================================
 * 3. Slice cap arithmetic
 * =================================================================================================
 */

/// An empty slice is worth nothing, whatever the mark stack looks like.
rule sliceCap_zero_amount_is_zero(uint256 lsAtReq, uint256 ethAtReq, uint256 start) {
    require lsAtReq > 0;
    assert sliceCap(lsAtReq, ethAtReq, start, 0) == 0;
}

/// With no marks at all, the cap is exactly the request-time value of the slice — the pre-SERL
/// behaviour. Together with `legacy_request_ignores_marks` this fixes both untouched baselines.
rule sliceCap_without_marks_is_request_rate(uint256 lsAtReq, uint256 ethAtReq, uint256 start, uint256 amount) {
    require getRateMarkCount() == 0;
    require lsAtReq > 0;
    require REALISTIC(to_mathint(lsAtReq)) && REALISTIC(to_mathint(ethAtReq)) && REALISTIC(to_mathint(amount));

    assert to_mathint(sliceCap(lsAtReq, ethAtReq, start, amount))
        == (to_mathint(amount) * to_mathint(ethAtReq)) / to_mathint(lsAtReq);
}

/// A slice that sits entirely above every mark is likewise valued at the request-time rate. This is
/// the gap case that keeps a fill funded from the deposit buffer — one that involved no exit and so
/// stopped no principal from earning — paying exactly `rate_at_request`.
rule sliceCap_above_all_marks_is_request_rate(uint256 lsAtReq, uint256 ethAtReq, uint256 start, uint256 amount) {
    require lsAtReq > 0;
    require REALISTIC(to_mathint(lsAtReq)) && REALISTIC(to_mathint(ethAtReq)) && REALISTIC(to_mathint(amount));
    require to_mathint(start) >= to_mathint(rateMarkCursor());       // starts past the end of the last mark

    assert to_mathint(sliceCap(lsAtReq, ethAtReq, start, amount))
        == (to_mathint(amount) * to_mathint(ethAtReq)) / to_mathint(lsAtReq);
}

/// Claiming more LsETH never entitles you to less ETH.
rule sliceCap_monotonic_in_amount(uint256 lsAtReq, uint256 ethAtReq, uint256 start, uint256 a, uint256 b) {
    require lsAtReq > 0;
    require REALISTIC(to_mathint(lsAtReq)) && REALISTIC(to_mathint(ethAtReq));
    require REALISTIC(to_mathint(a)) && REALISTIC(to_mathint(b));
    require to_mathint(a) <= to_mathint(b);

    assert to_mathint(sliceCap(lsAtReq, ethAtReq, start, a)) <= to_mathint(sliceCap(lsAtReq, ethAtReq, start, b));
}

/// Splitting a claim cannot pay more than claiming in one go. `claimRedeemRequests` exposes `_depth`
/// precisely so a long-pending request can be settled across several transactions; without this
/// property that knob would be an extraction lever, since each sub-slice re-enters `_sliceCap` and
/// re-rounds. Floor division makes the split lossy, never generous, hence `>=` rather than `==`.
rule sliceCap_splitting_never_pays_more(uint256 lsAtReq, uint256 ethAtReq, uint256 start, uint256 a, uint256 b) {
    require lsAtReq > 0;
    require REALISTIC(to_mathint(lsAtReq)) && REALISTIC(to_mathint(ethAtReq));
    require REALISTIC(to_mathint(start)) && REALISTIC(to_mathint(a)) && REALISTIC(to_mathint(b));

    uint256 ab;      require to_mathint(ab) == to_mathint(a) + to_mathint(b);
    uint256 mid;     require to_mathint(mid) == to_mathint(start) + to_mathint(a);

    uint256 whole = sliceCap(lsAtReq, ethAtReq, start, ab);
    uint256 first = sliceCap(lsAtReq, ethAtReq, start, a);
    uint256 second = sliceCap(lsAtReq, ethAtReq, mid, b);

    assert to_mathint(whole) >= to_mathint(first) + to_mathint(second);
}

/// A slice covered end to end by a single mark is valued at that mark's locked rate — the case the
/// whole mechanism exists for.
rule sliceCap_fully_covered_uses_marked_rate(uint256 lsAtReq, uint256 ethAtReq, uint256 start, uint256 amount) {
    require getRateMarkCount() == 1;
    require lsAtReq > 0 && amount > 0;
    require REALISTIC(to_mathint(lsAtReq)) && REALISTIC(to_mathint(ethAtReq)) && REALISTIC(to_mathint(amount));

    mathint markHeight = to_mathint(getRateMarkHeight(0));
    mathint markAmount = to_mathint(getRateMarkAmount(0));
    mathint markedEth = to_mathint(getRateMarkEth(0));
    require markAmount > 0;
    require REALISTIC(markAmount) && REALISTIC(markedEth) && REALISTIC(markHeight);
    require to_mathint(start) >= markHeight;
    require to_mathint(start) + to_mathint(amount) <= markHeight + markAmount;

    assert to_mathint(sliceCap(lsAtReq, ethAtReq, start, amount))
        == (to_mathint(amount) * markedEth) / markAmount;
}

/// Non-vacuity: a mark can in fact raise the ceiling above the request-time value. If this cannot be
/// satisfied, the feature is inert and every rule above holds trivially.
rule sliceCap_can_exceed_request_rate_witness(uint256 lsAtReq, uint256 ethAtReq, uint256 start, uint256 amount) {
    require lsAtReq > 0 && amount > 0;
    require REALISTIC(to_mathint(lsAtReq)) && REALISTIC(to_mathint(ethAtReq)) && REALISTIC(to_mathint(amount));

    uint256 cap = sliceCap(lsAtReq, ethAtReq, start, amount);

    satisfy to_mathint(cap) > (to_mathint(amount) * to_mathint(ethAtReq)) / to_mathint(lsAtReq);
}

/*
 * EXPECTED TO FAIL — kept deliberately, as a question rather than an assertion.
 *
 * A mark replaces the request-time rate over the range it covers; it does not take a maximum. If the
 * pool rate fell between a request being opened and the report that marks it, the locked rate is BELOW
 * the request-time rate and the cap over that range drops accordingly. That is arguably correct — the
 * redeemer should absorb a loss their principal actually took — but it is a behaviour change against
 * the pre-SERL cap, which only ever fell as ETH was paid out.
 *
 * Read the counterexample before deciding: if the intent is that a mark may only ever RAISE a
 * ceiling, `_sliceCap` case 3 needs a max() against the request-time rate and this becomes a real
 * rule. If the intent is that the mark simply reprices, delete this rule and record the decision.
 */
rule sliceCap_never_below_request_rate(uint256 lsAtReq, uint256 ethAtReq, uint256 start, uint256 amount) {
    require lsAtReq > 0;
    require REALISTIC(to_mathint(lsAtReq)) && REALISTIC(to_mathint(ethAtReq)) && REALISTIC(to_mathint(amount));

    assert to_mathint(sliceCap(lsAtReq, ethAtReq, start, amount))
        >= (to_mathint(amount) * to_mathint(ethAtReq)) / to_mathint(lsAtReq);
}

/*
 * =================================================================================================
 * 4. Claim path — solvency
 * =================================================================================================
 */

/// The solvency rule. A raised cap must never let a claim draw more ETH than the withdrawal event it
/// is settled against actually delivered for the matched LsETH. `_sliceCap` only relaxes a ceiling;
/// the payout is still `min(event pro-rata, cap)`, so the protocol can never pay out ETH it has not
/// received, no matter how the mark stack is arranged.
rule claim_payout_bounded_by_withdrawal_event_share(uint32 requestId, uint32 eventId) {
    env e;

    require to_mathint(requestId) < to_mathint(getRedeemRequestCount());
    require to_mathint(eventId) < to_mathint(getWithdrawalEventCount());

    mathint reqHeight = to_mathint(getRedeemRequestHeight(requestId));
    mathint reqAmount = to_mathint(getRedeemRequestAmount(requestId));
    mathint evtHeight = to_mathint(getWithdrawalEventHeight(eventId));
    mathint evtAmount = to_mathint(getWithdrawalEventAmount(eventId));
    mathint evtEth = to_mathint(getWithdrawalEventWithdrawnEth(eventId));

    require evtAmount > 0 && reqAmount > 0;
    require REALISTIC(reqAmount) && REALISTIC(evtAmount) && REALISTIC(evtEth);
    require reqHeight >= evtHeight && reqHeight < evtHeight + evtAmount;   // _isMatch

    mathint room = evtHeight + evtAmount - reqHeight;
    mathint matching = reqAmount < room ? reqAmount : room;

    RedeemQueueV2.RedeemRequest request = getRedeemRequestDetails(requestId);
    require request.recipient != currentContract;      // otherwise the payout never leaves the balance
    require e.msg.sender != currentContract;

    uint32[] requestIds;   require requestIds.length == 1 && requestIds[0] == requestId;
    uint32[] eventIds;     require eventIds.length == 1 && eventIds[0] == eventId;

    mathint balanceBefore = nativeBalances[currentContract];
    claimRedeemRequests(e, requestIds, eventIds, true, 0);             // depth 0: exactly one match step
    mathint balanceAfter = nativeBalances[currentContract];

    assert balanceBefore - balanceAfter <= (matching * evtEth) / evtAmount;
}

/// Exceeding ETH — the difference between what an event delivered and what the cap allowed — is only
/// ever released to River through `pullExceedingEth`. A raised cap shrinks this buffer; it must not be
/// able to drain it by any other route.
rule buffered_exceeding_eth_only_released_by_pull(method f)
    filtered { f -> !f.isView && !ignoredMethod(f) && f.selector != sig:pullExceedingEth(uint256).selector }
{
    uint256 before = getBufferedExceedingEth();
    env e; calldataarg args;
    f(e, args);
    assert getBufferedExceedingEth() >= before;
}

/// The end position of a request never moves. `_sliceCap` locates a slice by `redeemRequest.height`,
/// so if a claim could shift a request's end position it would relocate the request on the axis the
/// marks are placed on, and a later claim would be priced against someone else's marks.
rule claim_preserves_request_end_position(method f, uint32 id)
    filtered { f -> !f.isView && !ignoredMethod(f) }
{
    require to_mathint(id) < to_mathint(getRedeemRequestCount());
    mathint endBefore = to_mathint(getRedeemRequestHeight(id)) + to_mathint(getRedeemRequestAmount(id));

    env e; calldataarg args;
    f(e, args);

    mathint endAfter = to_mathint(getRedeemRequestHeight(id)) + to_mathint(getRedeemRequestAmount(id));
    assert endBefore == endAfter;
}
