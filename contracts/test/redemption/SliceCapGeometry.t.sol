//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionReportBase.sol";

/// @title Slice cap geometry tests
/// @notice Covers the ordered walk `_sliceCap` performs over a claimed slice, one geometry per test.
/// @dev `_sliceCap` splits the slice at every mark boundary and values each sub-range at
///      `markedEth / markAmount` where a mark covers it and at
///      `anchor.ethAtRequest / anchor.lsETHAtRequest` everywhere else. See `RedemptionReportBase` for
///      the axis model the three interval stacks share.
///
///      `_findRateMarkAtOrBefore` answers only "which is the last mark that starts at or before this
///      position". It does not promise that mark reaches the position, which is why the walk has a
///      `case 2` that discards a stale candidate.
///
/// @dev WHY EVERY EVENT HERE IS OVER-FUNDED, and only slightly. The payout is
///      `min(pro-rata of the event's ETH, cap)`, so each test funds its events at a settlement rate
///      strictly above the largest cap rate it relies on -- the request-time rate over unmarked spans,
///      a mark's locked rate over marked ones -- to make the cap the binding side. If the settlement
///      rate merely tied the binding cap rate the two sides of the `min()` would coincide and a broken
///      walk would still produce the asserted number.
///
///      The margin is small on purpose. River derives an event's pair from the single live pool rate
///      (`withdrawnEth = underlyingBalanceFromShares(amount)`), so an event funded at 2.0 against a
///      1.05 pool is unreachable. What these tests model instead is the ordinary sequence: a mark
///      locks the pre-report rate, the pool keeps appreciating across later reports, and the sweep is
///      priced at the higher post-report rate. A few percent of drift is enough for the cap to bind.
contract SliceCapGeometryTests is RedemptionReportBase {
    /// @dev Size of each mark pushed by `_pushRampMarks`.
    uint256 internal constant RAMP_MARK_SIZE = 1e18;
    /// @dev Locked rate of the first mark pushed by `_pushRampMarks`.
    uint256 internal constant RAMP_BASE_RATE = 1e18;
    /// @dev Locked-rate increment between consecutive `_pushRampMarks` marks.
    uint256 internal constant RAMP_RATE_STEP = 1e15;

    /// @dev Pushes `count` contiguous 1 LsETH marks whose locked rate climbs by one step per mark, and
    ///      returns the ETH they are collectively worth. Each mark being exactly 1 LsETH makes the
    ///      reported eth leg the locked rate, and River derives the LsETH leg as
    ///      `sharesFromUnderlyingBalance(eth)`, so every mark comes out 1 LsETH with no rounding.
    function _pushRampMarks(uint256 count) internal returns (uint256 totalMarkedEth) {
        for (uint256 i = 0; i < count; ++i) {
            uint256 rate = RAMP_BASE_RATE + i * RAMP_RATE_STEP;
            _reportRate(rate);
            uint256 markedEth = applyRate(RAMP_MARK_SIZE, rate);
            _reportStoppedEarning(markedEth);
            totalMarkedEth += markedEth;
        }
    }

    /// @dev Claims request `id` against `withdrawalEventId` with unbounded depth and reports the gas the
    ///      claim call itself burned, so the cost of the walk stays visible.
    function _claimMeasuringGas(uint32 id, uint32 withdrawalEventId)
        internal
        returns (uint256 received, uint256 gasUsed)
    {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = withdrawalEventId;

        address recipient = redeemManager.getRedeemRequestDetails(id).recipient;
        uint256 balanceBefore = recipient.balance;
        uint256 gasBefore = gasleft();
        redeemManager.claimRedeemRequests(ids, eventIds);
        gasUsed = gasBefore - gasleft();
        received = recipient.balance - balanceBefore;
    }

    /// D2. Scenario: the slice sits entirely above the one and only mark.
    ///
    ///     marks   [====== mark0 ======)
    ///     axis    0                  30                  60
    ///     slice                       [===== request B =====)
    ///
    /// The predecessor search still returns mark0 -- the last mark starting at or before 30 -- but
    /// mark0 ends at 30, so `case 2` discards it, `markIndex` walks off the end of the stack and the
    /// `markIndex >= markCount` return values the whole remainder at the request rate.
    ///
    /// Expected: B is paid 30 LsETH at its request rate of 1.0, and the 2.4 ETH of over-funding is
    /// confiscated to the exceeding buffer.
    function testSliceAboveLastMarkPaysRequestRate() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        _openRequest(user, 30e18); // A occupies [0, 30)
        uint32 b = _openRequest(user, 30e18); // B occupies [30, 60)

        // only the first 30 LsETH of demand is ever marked, so the stack ends at 30
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark0 = redeemManager.getRateMarkDetails(0);
        assertEq(mark0.height + mark0.amount, 30e18);

        // event 0 settles A's range at the live rate; event 1 then settles B's at 1.08, above both cap
        // rates in play (mark0's 1.05 and B's 1.0), so the cap binds rather than the event's ETH
        _reportWithdraw(30e18, 1.05e18);
        _reportRate(1.08e18);
        _reportWithdraw(30e18, 1.08e18);

        uint256 received = _claim(b);

        // the whole slice is above mark0, so nothing is credited at 1.05: 30 * 1.0
        assertEq(received, 30e18);
        // pro-rata ETH was 30 * 1.08 = 32.4; the 2.4 above the cap is confiscated
        assertEq(redeemManager.getBufferedExceedingEth(), 2.4e18);
    }

    /// D4. Scenario: the slice STARTS INSIDE a mark because an earlier partial claim already advanced
    /// `request.height` into the middle of it.
    ///
    ///     marks   [============== mark0 (40 LsETH @ 1.05) ==============)
    ///     axis    0                15                                  40
    ///     claim 1 [== slice 1 ====)
    ///     claim 2                  [============ slice 2 ==============)
    ///
    /// `case 3` fires on the second claim with `markedAmount = markEnd - sliceCursor = 40 - 15 = 25`,
    /// so only the residual of the mark is credited: the first claim already consumed [0, 15).
    ///
    /// Expected: 15.75 ETH then 26.25 ETH, summing to mark0's whole `markedEth` of 42 ETH -- the mark
    /// is neither double counted nor re-consumed from its start.
    function testSliceStartingInsideMarkCreditsResidualOnly() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 40e18); // occupies [0, 40)

        // the whole request is backed by principal that stopped earning at 1.05
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(40e18, 1.05e18));
        RateMarkStack.RateMark memory mark0 = redeemManager.getRateMarkDetails(0);
        assertEq(mark0.height, 0);
        assertEq(mark0.amount, 40e18);
        assertEq(mark0.markedEth, 42e18);

        // both events settle at 1.08, strictly above the only cap rate in play, mark0's 42/40 == 1.05
        _reportRate(1.08e18);
        // first fill covers only 15 of the 40 LsETH
        _reportWithdraw(15e18, 1.08e18);
        uint256 firstClaim = _claim(id);
        // slice [0, 15) inside mark0: 15 * 42 / 40
        assertEq(firstClaim, 15.75e18);
        // the request has been walked forward, so the next slice starts mid-mark
        assertEq(redeemManager.getRedeemRequestDetails(id).height, 15e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 25e18);

        // 16.2 ETH funded, 15.75 payable: 0.45 confiscated, which the report funding the second event
        // hands straight back to River (see the buffer note on `RedemptionReportBase`)
        assertEq(redeemManager.getBufferedExceedingEth(), 0.45e18);
        _reportWithdraw(25e18, 1.08e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        uint256 secondClaim = _claim(id);

        // slice [15, 40): case 3 credits markEnd - cursor = 25 LsETH at 42/40, and nothing else
        assertEq(secondClaim, 26.25e18);
        // the two halves reconstruct the mark exactly
        assertEq(firstClaim + secondClaim, mark0.markedEth);
        // 16.2 + 27 = 43.2 ETH funded, 42 payable. Of the 1.2 ETH confiscated across the two claims,
        // 0.45 has already gone back to River and 0.75 is still staged.
        assertEq(redeemManager.getBufferedExceedingEth(), 0.75e18);
    }

    /// D5b. Scenario: the slice ENDS INSIDE a mark, so `markedAmount` is clipped by `remainingAmount`
    /// rather than by the mark's end. The tail of the mark must survive for the request behind it.
    ///
    ///     marks   [================ mark0 (40 LsETH @ 1.05) ============)
    ///     axis    0                 20                                 40
    ///     slice A [== request A ====)
    ///     slice B                    [========= request B =============)
    ///
    /// Expected: A is paid 20 * 1.05 = 21 ETH from the covered prefix, and B -- a separate request
    /// sharing the same mark -- is paid 21 ETH too. Their sum is mark0's whole `markedEth`, which is
    /// what proves the clip did not consume the tail.
    function testSliceEndingInsideMarkLeavesTailForNextRequest() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 a = _openRequest(user, 20e18); // occupies [0, 20)
        uint32 b = _openRequest(user, 20e18); // occupies [20, 40)

        // one report marks both requests at once: the pooled-exit case, one exit backing two requests
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(40e18, 1.05e18));
        RateMarkStack.RateMark memory mark0 = redeemManager.getRateMarkDetails(0);
        assertEq(mark0.amount, 40e18);
        assertEq(mark0.markedEth, 42e18);

        // both events settle at 1.08, strictly above the only cap rate in play (mark0's 42/40 == 1.05),
        // so the cap binds in both claims
        _reportRate(1.08e18);
        _reportWithdraw(20e18, 1.08e18);
        uint256 receivedA = _claim(a);
        // slice [0, 20): markedAmount would be 40, clipped to remainingAmount = 20 -> 20 * 42 / 40
        assertEq(receivedA, 21e18);
        // 21.6 ETH funded, 21 payable: 0.6 confiscated
        assertEq(redeemManager.getBufferedExceedingEth(), 0.6e18);

        // the report that funds B's event also returns A's confiscated 0.6 ETH to River
        _reportWithdraw(20e18, 1.08e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        uint256 receivedB = _claim(b);
        // slice [20, 40): the untouched tail of the very same mark, 20 * 42 / 40
        assertEq(receivedB, 21e18);

        // the clip left the tail behind: the two claims reconstruct the mark
        assertEq(receivedA + receivedB, mark0.markedEth);
        // 21.6 + 21.6 = 43.2 ETH funded, 42 payable. Of the 1.2 ETH confiscated, half has gone back to
        // River and half is still staged.
        assertEq(redeemManager.getBufferedExceedingEth(), 0.6e18);
    }

    /// D6. Scenario: one request spans a gap between two marks -- the non-contiguity the RateMarkStack
    /// library header warns about. The gap is demand a withdrawal event settled with no exit behind
    /// it, so the settled height overtook the mark cursor and left a permanent hole in the stack.
    ///
    ///     marks   [== mark0 rate 1.05 ==)          [====== mark1 rate 1.10 =====)
    ///     axis    0                20         30                       60
    ///     gap                       [== gap ==)
    ///     request [============ request R (60 LsETH @ 1.00) ============)
    ///
    /// Expected: mark rate -> request rate -> mark rate, summed term by term:
    /// 20 * 1.05 + 10 * 1.00 + 30 * 1.10 = 21 + 10 + 33 = 64 ETH.
    ///
    /// @dev FINDING (Informational, coverage)
    ///      Claim: the blend resolves across two consecutive `_sliceCap` calls, not one, so a single
    ///        `_sliceCap` invocation is never observed stepping from a gap into the next mark.
    ///      Mechanism: `_isMatch` confines a slice to one withdrawal event, and a gap can only be
    ///        created by `settledHeight` overtaking the mark cursor -- so a gap always terminates on
    ///        an event boundary, and the mark above it starts on that same boundary. One invocation
    ///        can reach `case 1` for the gap but can never step past it.
    ///      Consequence: the claim-level blend below is the number that matters and is asserted; the
    ///        per-slice decomposition is asserted alongside it so the split stays visible if the
    ///        geometry changes.
    function testSliceSpanningGapBlendsMarkRequestMarkRates() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 60e18); // occupies [0, 60)

        // only the first 20 LsETH of the request is backed by an exit
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(20e18, 1.05e18));
        assertEq(_markCursor(), 20e18);

        // 30 LsETH is then settled from the deposit buffer -- no exit, so no mark -- pushing the
        // settled height past the mark cursor and opening the gap [20, 30). The pool has moved to 1.08
        // by the time it is swept, above both cap rates this slice uses (1.05 and 1.00).
        _reportRate(1.08e18);
        _reportWithdraw(30e18, 1.08e18);
        assertEq(_settledHeight(), 30e18);

        // the next report can only mark unsettled demand, so mark1 starts at 30, not at 20
        _reportRate(1.1e18);
        _reportStoppedEarning(applyRate(30e18, 1.1e18));
        assertEq(redeemManager.getRateMarkCount(), 2);
        assertEq(redeemManager.getRateMarkDetails(1).height, 30e18);
        assertEq(redeemManager.getRateMarkDetails(1).amount, 30e18);

        // the second sweep is priced at 1.13, above mark1's locked 1.10, so this slice is cap-bound too
        _reportRate(1.13e18);
        _reportWithdraw(30e18, 1.13e18);

        // one call walks event 0 then event 1 by recursion
        uint256 received = _claim(id);

        // slice [0, 30) = mark0 then case 1 over the gap: 20 * 1.05 + 10 * 1.00 = 31
        // slice [30, 60) = mark1 in full:                 30 * 1.10             = 33
        assertEq(received, 31e18 + 33e18);
        assertEq(received, 64e18);
        // 32.4 ETH funded at 1.08 plus 33.9 at 1.13 == 66.3, 64 payable
        assertEq(redeemManager.getBufferedExceedingEth(), 66.3e18 - 64e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 2.3e18);
    }

    /// D7. Scenario: one request spans four marks and the three gaps between them, each mark at a
    /// distinct locked rate so no two terms can be confused.
    ///
    ///     marks   [m0 rate 1.02)      [== m1 rate 1.04 ==)         [== m2 rate 1.06 ==)    [m3 rate 1.08)
    ///     axis    0       10     20              35       45              65  70        80        100
    ///     gaps             [=====)                [=======)                    [=======)          tail
    ///     request [========================= request R (100 LsETH @ 1.00) ===================)
    ///
    /// Expected: the blend equals the hand-computed sum term by term,
    /// 10*1.02 + 10*1.00 + 15*1.04 + 10*1.00 + 20*1.06 + 5*1.00 + 10*1.08 + 20*1.00 = 102.8 ETH,
    /// and the loop terminates -- the final 20 LsETH sits above the last mark and exits through the
    /// `markIndex >= markCount` return.
    ///
    /// @dev Per the finding on `testSliceSpanningGapBlendsMarkRequestMarkRates`, the four marks and
    ///      three gaps are walked across four consecutive slices, one per withdrawal event.
    function testWalkAcrossFourMarksAndThreeGapsSumsTermByTerm() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 100e18); // occupies [0, 100)

        // The pool ramps monotonically: each mark locks a pre-report rate and the sweep after it is
        // priced one step higher, putting every event above the largest cap rate its own slice uses.

        // mark0 = [0, 10) @ 1.02
        _reportRate(1.02e18);
        _reportStoppedEarning(applyRate(10e18, 1.02e18));
        // settling 20 at 1.03 leaves the gap [10, 20); cap rates here are 1.02 and 1.00
        _reportRate(1.03e18);
        _reportWithdraw(20e18, 1.03e18);

        // mark1 = [20, 35) @ 1.04, starting at the settled height
        _reportRate(1.04e18);
        _reportStoppedEarning(applyRate(15e18, 1.04e18));
        // settling 25 more at 1.05 leaves the gap [35, 45); cap rates 1.04 and 1.00
        _reportRate(1.05e18);
        _reportWithdraw(25e18, 1.05e18);

        // mark2 = [45, 65) @ 1.06
        _reportRate(1.06e18);
        _reportStoppedEarning(applyRate(20e18, 1.06e18));
        // settling 25 more at 1.07 leaves the gap [65, 70); cap rates 1.06 and 1.00
        _reportRate(1.07e18);
        _reportWithdraw(25e18, 1.07e18);

        // mark3 = [70, 80) @ 1.08, leaving [80, 100) permanently unmarked above the stack
        _reportRate(1.08e18);
        _reportStoppedEarning(applyRate(10e18, 1.08e18));
        _reportRate(1.09e18);
        _reportWithdraw(30e18, 1.09e18);

        // the geometry drawn above, asserted rather than assumed
        assertEq(redeemManager.getRateMarkCount(), 4);
        assertEq(redeemManager.getRateMarkDetails(0).height, 0);
        assertEq(redeemManager.getRateMarkDetails(0).amount, 10e18);
        assertEq(redeemManager.getRateMarkDetails(1).height, 20e18);
        assertEq(redeemManager.getRateMarkDetails(1).amount, 15e18);
        assertEq(redeemManager.getRateMarkDetails(2).height, 45e18);
        assertEq(redeemManager.getRateMarkDetails(2).amount, 20e18);
        assertEq(redeemManager.getRateMarkDetails(3).height, 70e18);
        assertEq(redeemManager.getRateMarkDetails(3).amount, 10e18);

        uint256 received = _claim(id);

        // marked terms, each at its own locked rate
        uint256 markedTerms = applyRate(10e18, 1.02e18) // mark0
            + applyRate(15e18, 1.04e18) // mark1
            + applyRate(20e18, 1.06e18) // mark2
            + applyRate(10e18, 1.08e18); // mark3
        // unmarked terms: three gaps of 10, 10 and 5 plus the 20 above the last mark, all at 1.00
        uint256 unmarkedTerms = applyRate(10e18 + 10e18 + 5e18 + 20e18, 1e18);
        assertEq(markedTerms, 57.8e18);
        assertEq(unmarkedTerms, 45e18);
        assertEq(received, markedTerms + unmarkedTerms);
        assertEq(received, 102.8e18);

        // the request is fully claimed, so the loop terminated on every one of the four slices
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
        // 20*1.03 + 25*1.05 + 25*1.07 + 30*1.09 = 20.6 + 26.25 + 26.75 + 32.7 = 106.3 ETH funded,
        // 102.8 payable; every one of the four slices was cap-bound, none of them event-bound
        assertEq(redeemManager.getBufferedExceedingEth(), 106.3e18 - 102.8e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 3.5e18);
    }

    /// D8. Scenario: the slice starts EXACTLY at the `markEnd` of its predecessor mark, with a gap
    /// above it. This is the `case 2` geometry: the predecessor search returns mark0 because mark0 is
    /// the last mark starting at or before 20, but mark0 terminates at 20 and so covers nothing.
    ///
    ///     marks   [== mark0 rate 1.05 ==)          [====== mark1 rate 1.10 =====)
    ///     axis    0                20         30                       60
    ///     slice                     [= slice =)
    ///
    /// Expected: `sliceCursor >= markEnd` fires, the stale mark0 is discarded, mark1 is tested next
    /// and found to start above the cursor, so `case 1` values the whole slice at the request rate.
    /// 10 LsETH * 1.00 = 10 ETH -- not 10.5 (mark0's rate) and not 11 (mark1's rate).
    function testSliceStartingAtPredecessorMarkEndTakesNoCreditFromIt() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        _openRequest(user, 20e18); // A occupies [0, 20)
        uint32 b = _openRequest(user, 40e18); // B occupies [20, 60)

        // mark0 covers A exactly, so it ends precisely at B's start height
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(20e18, 1.05e18));
        RateMarkStack.RateMark memory mark0 = redeemManager.getRateMarkDetails(0);
        assertEq(mark0.height + mark0.amount, 20e18);
        assertEq(redeemManager.getRedeemRequestDetails(b).height, 20e18);

        // one event settles A and the first 10 LsETH of B, priced at 1.12 -- above every rate the
        // assertions discriminate between: mark0's 1.05, mark1's 1.10 and B's 1.00
        _reportRate(1.12e18);
        _reportWithdraw(30e18, 1.12e18);

        // the next report can only mark unsettled demand, so mark1 opens at 30 and the gap [20, 30) --
        // B's first slice -- is left permanently unmarked. The pool has slipped back to 1.10 by then,
        // which is what mark1 locks: a mark records the pre-report rate, and nothing requires that to
        // be above the rate of the sweep before it.
        _reportRate(1.1e18);
        _reportStoppedEarning(applyRate(30e18, 1.1e18));
        assertEq(redeemManager.getRateMarkDetails(1).height, 30e18);

        uint256 received = _claim(b);

        // slice [20, 30): no credit from mark0 (would be 10.5) and none from mark1 (would be 11)
        assertEq(received, 10e18);
        // pro-rata ETH for the slice was 10 * 33.6 / 30 = 11.2, so 1.2 is confiscated
        assertEq(redeemManager.getBufferedExceedingEth(), 1.2e18);
        // B is only partially claimed, and its remainder now sits at mark1's start
        assertEq(redeemManager.getRedeemRequestDetails(b).height, 30e18);
        assertEq(redeemManager.getRedeemRequestDetails(b).amount, 30e18);
    }

    /// D9. Scenario: both ways `_findRateMarkAtOrBefore` can answer `(false, 0)`.
    ///
    ///   (a) the stack is empty, so the `length == 0` guard fires. The walk enters at index 0 and
    ///       immediately hits the `markIndex >= markCount` return.
    ///   (b) the slice sits strictly below the first mark's height, so the `rateMarks[0].height >
    ///       _height` guard fires. The walk enters at the head of the stack and `case 1` values the
    ///       whole slice at the request rate, clipping `unmarkedAmount` by `remainingAmount` because
    ///       the first mark starts far above the slice's end.
    ///
    ///     (b) marks                                     [==== mark0 rate 1.05 ====)
    ///         axis    0        30                      60                     90
    ///         slice   [= A ====)
    ///
    /// Expected: 30 ETH in both cases -- 30 LsETH at the request rate of 1.00.
    function testSliceBelowEveryMarkPaysRequestRate() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 a = _openRequest(user, 30e18); // occupies [0, 30)
        uint32 b = _openRequest(user, 30e18); // occupies [30, 60)

        // both ranges settle at 1.03, above the 1.00 request rate that caps both slices and above
        // nothing else, since no mark exists yet
        _reportRate(1.03e18);
        _reportWithdraw(30e18, 1.03e18);
        _reportWithdraw(30e18, 1.03e18);

        // (a) empty stack. B's slice starts at 30, so this exercises the `length == 0` guard at a
        // non-zero position rather than at the head of the axis.
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(_claim(b), 30e18);
        // 30.9 ETH pro-rata against a 30 ETH cap
        assertEq(redeemManager.getBufferedExceedingEth(), 0.9e18);

        // (b) a mark now exists, pushed above everything already settled, so A's slice is strictly
        // below it. C exists only to give the report markable demand to attach to. Opening C is a
        // deposit, not a report, so B's confiscated 0.9 ETH survives it; the rate move after it is a
        // report, and returns that 0.9 ETH to River.
        _openRequest(user, 30e18); // C occupies [60, 90)
        assertEq(redeemManager.getBufferedExceedingEth(), 0.9e18);
        _reportRate(1.05e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).height, 60e18);

        // A's slice is [0, 30), entirely below mark0's height of 60, so the search bails out before
        // the binary search and case 1 clips 60 - 0 = 60 down to the 30 LsETH in the slice
        assertEq(_claim(a), 30e18);

        // 30.9 ETH pro-rata against a 30 ETH cap, twice -- 1.8 confiscated in total, half already
        // returned to River by the rate move above
        assertEq(redeemManager.getBufferedExceedingEth(), 0.9e18);
    }

    /// D10. Scenario: the slice's start height equals a mark's `height` EXACTLY, with marks on both
    /// sides so the binary search genuinely iterates (five marks, three loop passes).
    ///
    ///     marks   [m0 )[m1 )[== m2 ==)[== m3 ==)[== m4 ==)
    ///             1.01 1.02   1.03      1.04      1.05
    ///     axis    0    5   10        20        30        40                 50
    ///     slice                       [================ request B ==========)
    ///
    /// Expected: the search returns the rightmost mark with `height <= 20`, m3 rather than m2. B is
    /// credited at 1.04 over [20, 30) -- 10.4 ETH, not m2's 10.3 -- then at 1.05 over [30, 40), then
    /// at the request rate over [40, 50). Total 10.4 + 10.5 + 10 = 30.9 ETH.
    function testSliceStartingExactlyOnMarkHeightSelectsThatMark() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        _openRequest(user, 20e18); // A occupies [0, 20)
        uint32 b = _openRequest(user, 30e18); // B occupies [20, 50)

        // five contiguous marks, each at its own locked rate so the terms are distinguishable
        _reportRate(1.01e18);
        _reportStoppedEarning(applyRate(5e18, 1.01e18)); // m0 [0, 5)
        _reportRate(1.02e18);
        _reportStoppedEarning(applyRate(5e18, 1.02e18)); // m1 [5, 10)
        _reportRate(1.03e18);
        _reportStoppedEarning(applyRate(10e18, 1.03e18)); // m2 [10, 20)
        _reportRate(1.04e18);
        _reportStoppedEarning(applyRate(10e18, 1.04e18)); // m3 [20, 30)
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(10e18, 1.05e18)); // m4 [30, 40)

        assertEq(redeemManager.getRateMarkCount(), 5);
        assertEq(redeemManager.getRateMarkDetails(2).height, 10e18);
        // B's start height coincides exactly with m3's height, the boundary the search must resolve
        assertEq(redeemManager.getRateMarkDetails(3).height, 20e18);
        assertEq(redeemManager.getRedeemRequestDetails(b).height, 20e18);

        // both events settle at 1.08, above every cap rate B's slice uses (1.04, 1.05 and its own 1.00)
        _reportRate(1.08e18);
        _reportWithdraw(20e18, 1.08e18);
        _reportWithdraw(30e18, 1.08e18);

        uint256 received = _claim(b);

        // m3's rate over [20, 30), not m2's: 10.4 rather than 10.3
        uint256 fromM3 = applyRate(10e18, 1.04e18);
        uint256 fromM4 = applyRate(10e18, 1.05e18);
        uint256 aboveStack = applyRate(10e18, 1e18);
        assertEq(fromM3, 10.4e18);
        assertEq(received, fromM3 + fromM4 + aboveStack);
        assertEq(received, 30.9e18);
        // 32.4 ETH pro-rata against a 30.9 cap
        assertEq(redeemManager.getBufferedExceedingEth(), 32.4e18 - 30.9e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 1.5e18);
    }

    /// D11. Scenario: a request that stayed pending across many marked reports (200 marks, one per
    /// report) is claimed in a single call, then the identical geometry is claimed again with a
    /// bounded `_depth` so the walk is split across four calls.
    ///
    ///     marks   [m0)[m1)[m2)...[m199)      each 1 LsETH, rate 1.000, 1.001, ... 1.199
    ///     axis    0   1   2   3        200
    ///     slice   [========== request ======)
    ///
    /// Expected: the single-call claim does not run out of gas and pays the hand-computed blend
    /// `sum(1 + i*0.001) for i in 0..199 = 200 + 19.9 = 219.9 ETH`; the depth-bounded claims sum to
    /// exactly the same figure. Iterations are bounded by the number of marks the slice spans, which
    /// is why the claimant of an old request can split it rather than being priced out.
    function testRequestSpanningManyMarksClaimsInOneCallAndSplitsIdentically() external {
        address user = _generateAllowlistedUser(0);

        // ---- phase 1: 200 marks, one withdrawal event, one unbounded claim ----
        _reportRate(1e18);
        uint32 single = _openRequest(user, 200e18); // occupies [0, 200)

        uint256 expected = _pushRampMarks(200);
        // sum of 1e18 + i*1e15 over i in [0, 200) = 200e18 + 1e15 * (199 * 200 / 2)
        assertEq(expected, 219.9e18);
        assertEq(redeemManager.getRateMarkCount(), 200);
        assertEq(_markCursor(), 200e18);

        // one event covering the whole request, settled at 1.25 -- above the ramp's highest locked
        // rate (m199's 1.199), so the cap binds everywhere
        _reportRate(1.25e18);
        _reportWithdraw(200e18, 1.25e18);
        (uint256 received, uint256 gasUsed) = _claimMeasuringGas(single, 0);

        // `emit log_named_uint` rather than `console.log`: this profile builds with via_ir, under which
        // the optimizer is free to prune console's unused staticcall, and the number would vanish
        emit log_named_uint("gas: single-call claim walking 200 rate marks", gasUsed);
        assertEq(received, expected);
        assertEq(redeemManager.getRedeemRequestDetails(single).amount, 0);
        // A regression ceiling, not a production estimate: a Foundry test body is one transaction, so
        // the reports above warmed the mark stack and a live claimant would pay cold-SLOAD prices. It
        // still moves the moment the per-mark work changes. Observed: ~311k for 200 marks.
        assertLt(gasUsed, 1_000_000);

        // ---- phase 2: the same 200-mark geometry, claimed with a bounded depth ----
        _reportRate(1e18);
        uint32 split = _openRequest(user, 200e18); // occupies [200, 400)

        // marks resume exactly at the settled height, so the second ramp mirrors the first
        uint256 expectedSplit = _pushRampMarks(200);
        assertEq(expectedSplit, expected);
        assertEq(redeemManager.getRateMarkCount(), 400);
        assertEq(redeemManager.getRateMarkDetails(200).height, 200e18);

        // eight events of 25 LsETH each at 1.25, as in phase 1. Every event boundary lands on a mark
        // boundary, so the split introduces no rounding of its own.
        _reportRate(1.25e18);
        for (uint256 i = 0; i < 8; ++i) {
            _reportWithdraw(25e18, 1.25e18);
        }

        // depth 1 means each call handles its starting event plus one recursion, so two events per
        // call and four calls in total; event ids 1..8 belong to this request
        uint256 splitTotal;
        for (uint32 eventId = 1; eventId <= 7; eventId += 2) {
            splitTotal += _claimWithDepth(split, eventId, 1);
        }

        assertEq(splitTotal, expected);
        assertEq(redeemManager.getRedeemRequestDetails(split).amount, 0);
    }

    /// D12. Scenario: the mark's locked rate is below the request rate, because the pool was in a
    /// drawdown when the backing principal crossed exit_epoch. The pool then fully recovers before the
    /// sweep.
    ///
    ///     rates   request 1.20  ->  mark 1.00  ->  settlement 1.20
    ///     marks   [========= mark0 (30 LsETH @ 1.00) =========)
    ///     axis    0                                          30
    ///     request [============ request R (30 LsETH @ 1.20) ==)
    ///
    /// Expected: 30 ETH -- not the 36 ETH the anchor is worth, nor the 36 ETH the event supplied.
    /// `case 3` re-prices the whole slice downwards to the mark's locked rate, and the 6 ETH the
    /// recovery restored is confiscated to `BufferedExceedingEth` for the holders who did not redeem.
    ///
    /// @dev The direction is what this test is for. Every other test here ramps the pool up, so
    ///      `mark.markedEth / mark.amount` stays at or above `anchor.ethAtRequest /
    ///      anchor.lsETHAtRequest` and `case 3` only raises the ceiling. This is the mirror image, and
    ///      it is supported: a mark is a two-sided re-pricing rather than a raise, so a redeemer
    ///      marked during a drawdown forfeits any later recovery on the marked span -- including a
    ///      `CoverageFundV1` payout, which is what restores the rate here. See the notes on
    ///      `_sliceCap`.
    /// @dev `assertLt(received, anchor.ethAtRequest)` is the assertion that fails the day a floor at
    ///      the request-time rate is introduced, so that change cannot land silently.
    function testMarkBelowRequestRateRePricesSliceDownwards() external {
        _upgradeToV1_3();
        address user = _generateAllowlistedUser(0);

        // the request is quoted at 1.20, so its anchor is worth 36 ETH
        _reportRate(1.2e18);
        uint32 id = _openRequest(user, 30e18);
        RedeemRequestAnchor.Anchor memory anchor = redeemManager.getRedeemRequestAnchor(id);
        assertEq(anchor.lsETHAtRequest, 30e18);
        assertEq(anchor.ethAtRequest, 36e18);

        // a report takes the pool to 1.00 and the principal crosses exit_epoch there. A mark is priced
        // at the pre-report rate, so this locks 1.00 over the whole request -- below its 1.20.
        _reportRate(1e18);
        _reportStoppedEarning(applyRate(30e18, 1e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 30e18);
        assertEq(mark.markedEth, 30e18);
        // cross-multiplied to avoid a truncation in the assertion itself: 30 * 30 < 36 * 30
        assertLt(mark.markedEth * anchor.lsETHAtRequest, anchor.ethAtRequest * mark.amount);

        // the pool fully recovers to 1.20 before the sweep, so the event carries 36 ETH -- the
        // request-time value, 6 ETH above the mark
        _reportRate(1.2e18);
        uint256 withdrawnEth = _reportWithdraw(30e18, 1.2e18);
        assertEq(withdrawnEth, 36e18);

        uint256 received = _claim(id);

        // the mark, not the anchor and not the event, decides the payout
        assertEq(received, 30e18);
        assertEq(received, mark.markedEth);
        assertLt(received, anchor.ethAtRequest);
        assertLt(received, withdrawnEth);
        // the recovery the redeemer forfeited goes back to the remaining holders
        assertEq(redeemManager.getBufferedExceedingEth(), 6e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
    }

    /// D13. Scenario: one report marks the whole queue during a drawdown, so a request anchored far
    /// above the locked rate inherits it. Quantifies how much of a request's value a single depressed
    /// mark can re-price away.
    ///
    ///     marks   [================ mark0 (200 LsETH @ 0.50) ================)
    ///     axis    0                        100                              200
    ///     request [==== A (100 LsETH @ 0.50) ==)[==== B (100 LsETH @ 2.00) ==)
    ///
    /// Expected: B, whose anchor is worth 200 ETH and whose pro-rata share of the event is also
    /// 200 ETH, receives 50 ETH -- a quarter of its request-time value. `reportStoppedEarning` sizes a
    /// mark from `totalRequestedHeight - markStart`, i.e. from the whole axis, so one report's locked
    /// rate lands on every request it reaches regardless of what each of them was quoted at.
    ///
    /// @dev A is not the interesting case -- quoted at the same 0.50 the mark locks, its cap is
    ///      unchanged either way. B is: nothing about B's own history is depressed, only the pool rate
    ///      at the instant an unrelated pooled exit crossed exit_epoch.
    function testSingleDrawdownMarkRePricesAHigherRateRequest() external {
        _upgradeToV1_3();
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);

        // A is quoted cheaply, B expensively: the pool quadruples between the two requests
        _reportRate(0.5e18);
        uint32 idA = _openRequest(userA, 100e18); // [0, 100), anchored at 50 ETH
        _reportRate(2e18);
        uint32 idB = _openRequest(userB, 100e18); // [100, 200), anchored at 200 ETH
        assertEq(redeemManager.getRedeemRequestAnchor(idA).ethAtRequest, 50e18);
        assertEq(redeemManager.getRedeemRequestAnchor(idB).ethAtRequest, 200e18);
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, 100e18);

        // the pool is slashed back to 0.50 and a single pooled exit crosses exit_epoch there. markable
        // is the whole axis, so one mark covers both requests at the depressed rate.
        _reportRate(0.5e18);
        _reportStoppedEarning(applyRate(200e18, 0.5e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 200e18);
        assertEq(mark.markedEth, 100e18);

        // full recovery to 2.00 before the sweep: the event carries 400 ETH for the 200 LsETH it
        // settles, so B's pro-rata share is the full 200 ETH its anchor is worth
        _reportRate(2e18);
        assertEq(_reportWithdraw(200e18, 2e18), 400e18);

        uint256 receivedB = _claim(idB);

        // B is held to the mark's 0.50 over its whole span: 100 * 100 / 200
        assertEq(receivedB, 50e18);
        assertEq(receivedB, (100e18 * mark.markedEth) / mark.amount);
        // a quarter of what B was quoted, and a quarter of what the event offered it
        assertEq(receivedB * 4, redeemManager.getRedeemRequestAnchor(idB).ethAtRequest);
        assertEq(redeemManager.getBufferedExceedingEth(), 150e18);

        // A, quoted at the same rate the mark locks, is unaffected by the re-pricing
        uint256 receivedA = _claim(idA);
        assertEq(receivedA, 50e18);
        assertEq(receivedA, redeemManager.getRedeemRequestAnchor(idA).ethAtRequest);
        assertEq(redeemManager.getRedeemRequestDetails(idA).amount, 0);
    }
}
