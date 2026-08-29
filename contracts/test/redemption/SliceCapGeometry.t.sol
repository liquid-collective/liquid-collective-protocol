//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionReportBase.sol";

/// @title Slice cap geometry tests
/// @notice Covers the ordered walk `_sliceCap` performs over a claimed slice, one geometry per test.
/// @dev MODEL, restated so the numbers below can be read without the source open. All LsETH ever
///      queued forms one ascending cumulative axis. A claim matches a SLICE
///      `[request.height, request.height + matchingAmount)` of that axis against exactly one
///      withdrawal event. Rate marks are ascending, disjoint intervals on the same axis, and NOT
///      contiguous -- a gap means "no locked rate applies here", so that sub-range keeps the
///      request-time rate. `_sliceCap` splits the slice at every mark boundary and values each
///      sub-range at `markedEth / markAmount` where a mark covers it and at
///      `anchor.ethAtRequest / anchor.lsETHAtRequest` everywhere else.
///
///      The cap only ever raises a ceiling: the payout is
///      `min(pro-rata of the withdrawal event's ETH, cap)` and the excess is routed to
///      `BufferedExceedingEth`. Every test below therefore funds its withdrawal events at a settlement
///      rate STRICTLY ABOVE the largest cap rate it relies on -- the request-time rate over unmarked
///      spans, a mark's locked rate over marked ones -- so that what lands in the recipient's balance is
///      the cap itself and not the event's ETH. If the settlement rate merely tied the binding cap rate
///      the two sides of the `min()` would coincide and a broken walk would still produce the asserted
///      number; the strict inequality is what keeps these tests discriminating.
///
///      The margin is deliberately small, and every event is priced at the pool rate live when it is
///      reported. River derives a withdrawal event's pair from that single rate
///      (`withdrawnEth = underlyingBalanceFromShares(amount)`, see `_poolRate` on the base contract), so
///      an event funded at 2.0 against a 1.05 pool is not a state the protocol can reach. What IS
///      reachable, and what these tests model, is the ordinary sequence: a mark locks the PRE-report
///      pool rate, the pool then keeps appreciating across subsequent reports, and the sweep that
///      settles the demand is priced at the later, higher POST-report rate. A few percent of drift is
///      enough for the cap to bind; the over-funding never has to be extravagant to be visible.
///
///      `_findRateMarkAtOrBefore` answers only "which is the last mark that STARTS at or before this
///      position". It does not promise that mark reaches the position, which is why the walk has a
///      `case 2` that discards a stale candidate.
contract SliceCapGeometryTests is RedemptionReportBase {
    /// @dev Size of each mark pushed by `_pushRampMarks`.
    uint256 internal constant RAMP_MARK_SIZE = 1e18;
    /// @dev Locked rate of the first mark pushed by `_pushRampMarks`.
    uint256 internal constant RAMP_BASE_RATE = 1e18;
    /// @dev Locked-rate increment between consecutive `_pushRampMarks` marks.
    uint256 internal constant RAMP_RATE_STEP = 1e15;

    /// @dev Pushes `count` contiguous 1 LsETH marks whose locked rate climbs by one step per mark, and
    ///      returns the exact ETH those marks are collectively worth. Because each mark is exactly
    ///      1 LsETH the reported eth leg IS the locked rate, and River derives the LsETH leg as
    ///      `sharesFromUnderlyingBalance(eth)`, so every mark comes out exactly 1 LsETH with no rounding.
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
    /// The predecessor search still returns mark0 -- it is the last mark starting at or before 30 --
    /// but mark0 ENDS at 30, so `case 2` discards it, `markIndex` walks off the end of the stack and
    /// the `markIndex >= markCount` early return values the whole remainder at the request rate.
    ///
    /// Expected: B is paid 30 LsETH at its request rate of 1.0, i.e. 30 ETH, and the 2.4 ETH of
    /// over-funding is confiscated to the exceeding buffer.
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

        // event 0 settles A's range at the rate live when it is swept. The pool then appreciates once
        // more, and event 1 settles B's range at 1.08 -- above BOTH cap rates in play, mark0's 1.05 and
        // B's request rate of 1.0 -- so the cap is what binds rather than the event's ETH.
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
    /// `case 3` fires on the second claim with `markedAmount = markEnd - sliceCursor = 40 - 15 = 25`:
    /// only the residual part of the mark is credited, because the first claim already consumed
    /// [0, 15) of it.
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

        // the pool appreciates once more after the mark locked 1.05, so both events settle at 1.08 --
        // strictly above the only cap rate in play, mark0's locked 42/40 == 1.05
        _reportRate(1.08e18);
        // first fill covers only 15 of the 40 LsETH
        _reportWithdraw(15e18, 1.08e18);
        uint256 firstClaim = _claim(id);
        // slice [0, 15) inside mark0: 15 * 42 / 40
        assertEq(firstClaim, 15.75e18);
        // the request has been walked forward, so the next slice starts mid-mark
        assertEq(redeemManager.getRedeemRequestDetails(id).height, 15e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 25e18);

        // 16.2 ETH funded, 15.75 payable: 0.45 confiscated, and the report that funds the second event
        // hands it straight back to River -- `_pullRedeemManagerExceedingEth` runs on every report with
        // headroom to the APR upper bound, so the buffer is a per-report staging area, not a running total
        assertEq(redeemManager.getBufferedExceedingEth(), 0.45e18);
        _reportWithdraw(25e18, 1.08e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        uint256 secondClaim = _claim(id);

        // slice [15, 40): case 3 credits markEnd - cursor = 25 LsETH at 42/40, and nothing else
        assertEq(secondClaim, 26.25e18);
        // the two halves of the mark reconstruct it exactly, no more and no less
        assertEq(firstClaim + secondClaim, mark0.markedEth);
        // 16.2 + 27 = 43.2 ETH was funded, 42 was payable. Of the 1.2 ETH confiscated across the two
        // claims, 0.45 has already gone back to River and 0.75 is still staged here.
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
    /// Expected: A is paid 20 * 1.05 = 21 ETH from the covered prefix, and B -- an entirely separate
    /// request that shares the same mark -- is paid 21 ETH too. Their sum is mark0's whole
    /// `markedEth`, which is what proves the clip did not consume the tail.
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

        // the pool appreciates once more after the mark locked 1.05, so both events settle at 1.08 --
        // strictly above the only cap rate in play, mark0's locked 42/40 == 1.05 -- and the cap binds in
        // both claims
        _reportRate(1.08e18);
        _reportWithdraw(20e18, 1.08e18);
        uint256 receivedA = _claim(a);
        // slice [0, 20): markedAmount would be 40, clipped to remainingAmount = 20 -> 20 * 42 / 40
        assertEq(receivedA, 21e18);
        // 21.6 ETH funded, 21 payable: 0.6 confiscated
        assertEq(redeemManager.getBufferedExceedingEth(), 0.6e18);

        // the report that funds B's event also RETURNS A's confiscated 0.6 ETH to River, because
        // `_pullRedeemManagerExceedingEth` runs on every report with headroom to the APR upper bound.
        // The buffer is a per-report staging area, not a running total.
        _reportWithdraw(20e18, 1.08e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        uint256 receivedB = _claim(b);
        // slice [20, 40): the untouched tail of the very same mark, 20 * 42 / 40
        assertEq(receivedB, 21e18);

        // the clip left exactly the tail behind: the two claims reconstruct the mark
        assertEq(receivedA + receivedB, mark0.markedEth);
        // 21.6 + 21.6 = 43.2 ETH funded, 42 payable. Of the 1.2 ETH confiscated across the two claims,
        // half has already gone back to River and half is still staged here.
        assertEq(redeemManager.getBufferedExceedingEth(), 0.6e18);
    }

    /// D6. Scenario: one request spans a GAP between two marks. This is precisely the non-contiguity
    /// the RateMarkStack library header warns about -- the gap is demand that a withdrawal event settled
    /// without any exit behind it, so the mark cursor was overtaken by the settled height and a
    /// permanent hole was left in the stack.
    ///
    ///     marks   [== mark0 rate 1.05 ==)          [====== mark1 rate 1.10 =====)
    ///     axis    0                20         30                       60
    ///     gap                       [== gap ==)
    ///     request [============ request R (60 LsETH @ 1.00) ============)
    ///
    /// Expected: mark rate -> request rate -> mark rate, summed term by term:
    /// 20 * 1.05 + 10 * 1.00 + 30 * 1.10 = 21 + 10 + 33 = 64 ETH.
    ///
    /// @dev FINDING: the walk resolves this blend across TWO consecutive `_sliceCap` calls, not one.
    ///      A slice is confined to a single withdrawal event by `_isMatch`, and a gap can only ever be
    ///      created by `settledHeight` overtaking the mark cursor -- so a gap always terminates
    ///      exactly ON a withdrawal event boundary, and the mark above it always starts exactly on
    ///      that same boundary. A single `_sliceCap` invocation can therefore reach `case 1` for a gap
    ///      but can never step past it into the next mark. The blend asserted here is the claim-level
    ///      one, which is the number that matters; the per-slice decomposition is asserted alongside
    ///      it so the split stays visible if the geometry ever changes.
    function testSliceSpanningGapBlendsMarkRequestMarkRates() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 60e18); // occupies [0, 60)

        // only the first 20 LsETH of the request is backed by an exit
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(20e18, 1.05e18));
        assertEq(_markCursor(), 20e18);

        // 30 LsETH is then settled from the deposit buffer -- no exit, so no mark -- which pushes the
        // settled height past the mark cursor and opens the gap [20, 30). The pool has moved on to 1.08
        // by the time it is swept, above both cap rates this slice uses (mark0's 1.05 and the request's
        // 1.00), so the cap and not the event is what binds.
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

        // claiming in one call walks event 0 then event 1 by recursion
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
    /// deliberately different locked rate so no two terms can be confused.
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
    /// @dev See the FINDING on testSliceSpanningGapBlendsMarkRequestMarkRates: the four marks and
    ///      three gaps are walked across four consecutive slices, one per withdrawal event, because a
    ///      gap can never sit strictly inside a single event's range.
    function testWalkAcrossFourMarksAndThreeGapsSumsTermByTerm() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 100e18); // occupies [0, 100)

        // The pool ramps monotonically throughout: each mark locks a PRE-report rate and the sweep that
        // follows it is priced one step higher, which is exactly what puts every event strictly above
        // the largest cap rate its own slice uses.

        // mark0 = [0, 10) @ 1.02
        _reportRate(1.02e18);
        _reportStoppedEarning(applyRate(10e18, 1.02e18));
        // settling 20 at 1.03 leaves the gap [10, 20); slice cap rates here are 1.02 and 1.00
        _reportRate(1.03e18);
        _reportWithdraw(20e18, 1.03e18);

        // mark1 = [20, 35) @ 1.04, starting at the settled height
        _reportRate(1.04e18);
        _reportStoppedEarning(applyRate(15e18, 1.04e18));
        // settling 25 more at 1.05 leaves the gap [35, 45); slice cap rates here are 1.04 and 1.00
        _reportRate(1.05e18);
        _reportWithdraw(25e18, 1.05e18);

        // mark2 = [45, 65) @ 1.06
        _reportRate(1.06e18);
        _reportStoppedEarning(applyRate(20e18, 1.06e18));
        // settling 25 more at 1.07 leaves the gap [65, 70); slice cap rates here are 1.06 and 1.00
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
    /// the last mark starting at or before 20, but mark0 terminates AT 20 and so covers nothing.
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

        // one event settles A and the first 10 LsETH of B. It is priced at 1.12, the pool rate live when
        // it is swept, which is above every rate the assertions below discriminate between: mark0's
        // 1.05, mark1's 1.10 and B's request rate of 1.00.
        _reportRate(1.12e18);
        _reportWithdraw(30e18, 1.12e18);

        // the following report can only mark unsettled demand, so mark1 opens at 30 and the gap
        // [20, 30) -- which is exactly B's first slice -- is left permanently unmarked. The pool has
        // slipped back to 1.10 by then, which is what mark1 locks: a mark records the PRE-report rate,
        // and nothing requires it to be above the rate of the sweep that preceded it.
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
    ///       _height` guard fires. The walk enters at the HEAD of the stack and `case 1` values the
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

        // the pool appreciates to 1.03 and both ranges are settled at it -- above the 1.00 request rate
        // that caps both slices, and also above nothing else, since no mark exists yet
        _reportRate(1.03e18);
        _reportWithdraw(30e18, 1.03e18);
        _reportWithdraw(30e18, 1.03e18);

        // (a) empty stack. B's slice starts at 30, so this exercises the `length == 0` guard at a
        // non-zero position rather than at the head of the axis.
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(_claim(b), 30e18);
        // 30.9 ETH pro-rata against a 30 ETH cap
        assertEq(redeemManager.getBufferedExceedingEth(), 0.9e18);

        // (b) a mark now exists, but it is pushed above everything already settled, so A's slice is
        // strictly below it. C exists only to give the report some markable demand to attach to.
        // Opening C is a deposit rather than a report, so B's confiscated 0.9 ETH survives it; the rate
        // move that follows is a report, and returns that 0.9 ETH to River.
        _openRequest(user, 30e18); // C occupies [60, 90)
        assertEq(redeemManager.getBufferedExceedingEth(), 0.9e18);
        _reportRate(1.05e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).height, 60e18);

        // A's slice is [0, 30), entirely below mark0's height of 60: the search bails out before the
        // binary search runs and case 1 clips 60 - 0 = 60 down to the 30 LsETH actually in the slice
        assertEq(_claim(a), 30e18);

        // 30.9 ETH pro-rata against a 30 ETH cap, twice -- 1.8 ETH confiscated in total, half of it
        // already returned to River by the rate move above
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
    /// Expected: the search returns the RIGHTMOST mark with `height <= 20`, which is m3 and not m2.
    /// B is therefore credited at 1.04 over [20, 30) -- 10.4 ETH, not m2's 10.3 -- then at 1.05 over
    /// [30, 40), then at the request rate over [40, 50). Total 10.4 + 10.5 + 10 = 30.9 ETH.
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

        // the pool appreciates once more past the last mark's 1.05, so both events settle at 1.08 --
        // above every cap rate B's slice uses (1.04, 1.05 and its own 1.00) and the cap binds
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

    /// D11. Scenario: a request that stayed pending across MANY marked reports (200 marks, one per
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

        // one event covering the whole request, settled at 1.25 -- above the highest locked rate in the
        // ramp (m199's 1.199) and so above every per-mark term, which makes the cap bind everywhere
        _reportRate(1.25e18);
        _reportWithdraw(200e18, 1.25e18);
        (uint256 received, uint256 gasUsed) = _claimMeasuringGas(single, 0);

        // `emit log_named_uint` rather than `console.log`: this profile builds with via_ir, under which
        // the optimizer is free to prune console's unused staticcall, and the number would vanish
        emit log_named_uint("gas: single-call claim walking 200 rate marks", gasUsed);
        assertEq(received, expected);
        assertEq(redeemManager.getRedeemRequestDetails(single).amount, 0);
        // A regression ceiling rather than a target, and a floor rather than a production estimate:
        // a Foundry test body is one transaction, so the mark stack was already warmed by the reports
        // above and a live claimant would pay the cold-SLOAD price on every slot. It still moves the
        // moment the per-mark work changes, which is the point. Observed: ~311k for 200 marks.
        assertLt(gasUsed, 1_000_000);

        // ---- phase 2: the same 200-mark geometry, claimed with a bounded depth ----
        _reportRate(1e18);
        uint32 split = _openRequest(user, 200e18); // occupies [200, 400)

        // marks resume exactly at the settled height, so the second ramp mirrors the first
        uint256 expectedSplit = _pushRampMarks(200);
        assertEq(expectedSplit, expected);
        assertEq(redeemManager.getRateMarkCount(), 400);
        assertEq(redeemManager.getRateMarkDetails(200).height, 200e18);

        // eight events of 25 LsETH each, all settled at 1.25 as in phase 1: every event boundary lands
        // on a mark boundary, so the split introduces no rounding of its own, and every slice is
        // cap-bound because 1.25 is above the highest locked rate the ramp reaches
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
}
