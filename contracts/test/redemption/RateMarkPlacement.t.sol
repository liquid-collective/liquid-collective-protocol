//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionReportBase.sol";

/// @title Rate mark placement tests
/// @notice Covers where `reportStoppedEarning` puts a mark, and when it refuses to put one at all.
/// @dev `reportStoppedEarning` places each mark at `max(lastMarkEnd, settledHeight, rateMarkFloor)`
///      and sizes it at `min(reportedLsETH, totalRequestedHeight - markStart)`. For the axis model
///      the positions live on, see `RedemptionReportBase`.
///
///      RedeemManager.1.t.sol pins the payout consequences of a mark. This suite pins the placement
///      arithmetic, plus the four early-return paths that discard a reported delta: a zero eth leg, a
///      zero LsETH leg, an empty queue, and nothing left to mark after the clamp. Only the last is
///      observable through an event.
contract RateMarkPlacementTests is RedemptionReportBase {
    /// @dev Walks the whole mark stack and asserts the structural invariants that hold after every
    ///      report, whatever it contained.
    /// @param lastRequestId The newest request, whose end position is the top of the axis.
    function _assertMarkStackWellFormed(uint32 lastRequestId) internal {
        RedeemQueueV2.RedeemRequest memory lastRequest = redeemManager.getRedeemRequestDetails(lastRequestId);
        uint256 totalRequestedHeight = lastRequest.height + lastRequest.amount;

        uint256 count = redeemManager.getRateMarkCount();
        uint256 previousEnd = 0;
        for (uint256 idx = 0; idx < count; ++idx) {
            RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(uint32(idx));

            assertGt(mark.amount, 0, "empty mark pushed");
            // a mark may sit in a gap above the previous one, but may never reach back into it
            assertGe(mark.height, previousEnd, "marks overlap");
            // implied by the two above, but it is what `_findRateMarkAtOrBefore` binary-searches on
            if (idx > 0) {
                assertGt(mark.height, previousEnd - 1, "mark heights not strictly ascending");
            }
            previousEnd = mark.height + mark.amount;
            assertLe(previousEnd, totalRequestedHeight, "mark end past total requested height");
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C7 — degenerate legs
    // ─────────────────────────────────────────────────────────────────────────

    /// Scenario: a zero ETH leg against a non-zero LsETH leg, with markable demand pending.
    /// Expected: the first guard returns immediately -- no mark and no event, not even
    /// `StoppedEarningExceededMarkableDemand` -- leaving the pending demand as it was.
    /// @dev Defensive coverage on the external entry point. River cannot produce this pair: the LsETH
    ///      leg is derived from the eth leg (`sharesFromUnderlyingBalance`, LibOracleReporting
    ///      L217-219) and the call is gated on `stoppedEarningAmountIncrease > 0` (L392). Since the
    ///      report path cannot construct it, the call is made as River, which is what `onlyRiver`
    ///      gates. For the reachable forms of a discarded delta see
    ///      `testStoppedEarningWithOnlyLegacyDemandIsDiscardedPermanently` and
    ///      `testReportStoppedEarningOnEmptyQueueIsDropped`.
    function testReportStoppedEarningWithZeroEthLegIsDiscarded() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        // 30 LsETH pending and fully markable: nothing settled, no mark, floor at 0
        uint32 id = _openRequest(user, 30e18);
        assertEq(redeemManager.getRateMarkCount(), 0);

        // a delta claiming 30 LsETH stopped earning but valuing it at 0 eth
        vm.recordLogs();
        vm.prank(address(river));
        redeemManager.reportStoppedEarning(0, 30e18);

        // the guard fires before the clamp, so not even the exceeded-demand event is emitted
        _assertRedeemManagerSilent("zero eth leg must make the redeem manager emit nothing");
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(_markCursor(), 0);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // the rejected call leaves the request on the unmarked path, so it is paid at its own request
        // rate of 1.0 even though the pool has since risen to 1.05
        _reportRate(1.05e18);
        assertEq(_settleAndClaim(id, 30e18, 1.05e18), applyRate(30e18, 1e18));
        assertEq(redeemManager.getBufferedExceedingEth(), applyRate(30e18, 1.05e18) - applyRate(30e18, 1e18));
    }

    /// Scenario: 1 wei of principal at a pool rate above 1.0, so River's own conversion truncates the
    /// LsETH leg to zero: `sharesFromUnderlyingBalance(1) == 1 * 1e18 / 1.05e18 == 0`.
    /// Expected: early return at the dual-nonzero guard. No mark, no event, and the report path is not
    /// poisoned for the well-formed delta that follows.
    /// @dev The only reachable way into the zero-LsETH-leg guard: against a pool that has shares a
    ///      zero LsETH leg can only come from a dust eth leg. The guard is a cheap early-out, not what
    ///      makes the clamped-mark division safe -- a zero `reportedLsETH` forces `lsETHToMark == 0`,
    ///      so the clamp is skipped before the `lsETHToMark == 0` return fires. The denominator bound
    ///      is pinned in `testClampedMarkDivisionOnlyRunsWithADenominatorOfTwoOrMore`.
    function testReportStoppedEarningWithZeroLsETHLegIsDiscarded() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // the pool has appreciated to 1.05, so 1 wei of principal converts to zero shares
        _reportRate(1.05e18);
        vm.recordLogs();
        _reportStoppedEarning(1);

        _assertRedeemManagerSilent("zero LsETH leg must make the redeem manager emit nothing");
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(_markCursor(), 0);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // a well-formed delta at the same rate still marks normally
        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).height, 0);
        assertEq(redeemManager.getRateMarkDetails(0).amount, 30e18);

        // and only that second delta is reflected in the payout
        assertEq(_settleAndClaim(id, 30e18, 1.05e18), applyRate(30e18, 1.05e18));
    }

    /// Scenario: the tightest state in which the clamped-mark rescaling
    /// `(_stoppedEarningEth * lsETHToMark) / reportedLsETH` executes -- 1 wei of markable demand
    /// against a reported LsETH leg of 2 wei.
    /// Expected: the division runs with a denominator of 2 and truncates 3/2 down to 1 wei.
    /// @dev Pins the denominator bound. The rescaling is reached only from the
    ///      `lsETHToMark > markable` branch and only past the `lsETHToMark == 0` return, so
    ///      `reportedLsETH > markable == lsETHToMark >= 1` and the denominator is at least 2 by
    ///      construction. Two is the smallest it can be handed: `reportedLsETH == 1` would need
    ///      `markable == 0` to clamp, which returns at `lsETHToMark == 0` instead.
    /// @dev Both legs are ones River computes at the rate in force when reported --
    ///      `sharesFromUnderlyingBalance(3) == 2` at 1.5, `underlyingBalanceFromShares(1) == 3` at
    ///      3.0 -- so request 1.0 < mark 1.5 < settlement 3.0 is an ordinary appreciating sequence.
    function testClampedMarkDivisionOnlyRunsWithADenominatorOfTwoOrMore() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        // exactly 1 wei of markable demand, so `markable == 1` is the clamp target
        uint32 id = _openRequest(user, 1);

        // 2 wei of principal worth 3 wei: over-reported, so the eth leg is rescaled, which is the only
        // path that divides. Asked for loosely because a 1 wei position leaves a supply no fractional
        // rate divides; the conversion it produces is what matters and is pinned below.
        _reportRateLoose(1.5e18);
        assertEq(river.sharesFromUnderlyingBalance(3), 2, "the 3 wei eth leg must be valued at 2 wei of LsETH");
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(2, 1);
        _reportStoppedEarning(3);

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 1);
        // (3 * 1) / 2 == 1, truncated down from 1.5
        assertEq(mark.markedEth, 1);
        assertEq(mark.markedEth, (uint256(3) * mark.amount) / 2);
        _assertMarkStackWellFormed(id);

        // the division's result is what the redeemer is held to: an event offering 3 wei for the 1 wei
        // of demand is clamped to the locked 1 wei
        _reportRate(3e18);
        assertEq(_reportWithdraw(1, 3e18), 3);
        assertEq(_claim(id), 1);
        assertEq(redeemManager.getBufferedExceedingEth(), 2);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C8 — empty queue
    // ─────────────────────────────────────────────────────────────────────────

    /// Scenario: a well-formed stopped-earning delta lands while the redeem queue is empty, then a
    /// request is opened immediately afterwards.
    /// Expected: the `requestCount == 0` guard returns before `totalRequestedHeight` is read, so the
    /// delta is dropped. The request that follows gets no retroactive credit.
    /// @dev Nobody was waiting, so nothing is owed: the credit exists to compensate demand sitting in
    ///      the exit queue while the principal backing it stopped earning, and there was none.
    function testReportStoppedEarningOnEmptyQueueIsDropped() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        assertEq(redeemManager.getRedeemRequestCount(), 0);

        // 100 LsETH of principal stops earning, valued at the pool rate in force
        vm.recordLogs();
        _reportStoppedEarning(applyRate(100e18, 1e18));

        // the empty-queue guard precedes the clamp, so not even the exceeded-demand event fires
        // despite the whole 100 LsETH being unmarkable
        _assertRedeemManagerSilent("an empty queue must make the redeem manager emit nothing");
        assertEq(redeemManager.getRateMarkCount(), 0);

        uint32 id = _openRequest(user, 30e18);
        assertEq(redeemManager.getRateMarkCount(), 0, "no mark may appear retroactively");

        // the request settles at 1.05 but is paid at its own 1.0. Had the dropped delta carried
        // forward, a mark over [0, 30) would have raised this cap and the payout with it.
        _reportRate(1.05e18);
        assertEq(_settleAndClaim(id, 30e18, 1.05e18), applyRate(30e18, 1e18));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C9 — clamped credit does not carry forward
    // ─────────────────────────────────────────────────────────────────────────

    /// Scenario: a delta far larger than the pending demand is reported, so most of it is clamped
    /// away. A new request then arrives in the next block.
    /// Expected: the clamped-away portion is dropped, not carried. The new request sits in a mark gap
    /// and is paid at its own request rate; only a delta reported after it was queued could mark it.
    function testClampedCreditDoesNotAttachToLaterRequest() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 requestA = _openRequest(user, 30e18); // [0, 30) at rate 1.0

        // 100 LsETH stops earning at 1.05, but only A's 30 LsETH is markable
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(100e18, 30e18);
        _reportStoppedEarning(applyRate(100e18, 1.05e18));

        // exactly one mark, sized to the markable demand and priced at the reported rate. The 70 LsETH
        // of clamped-away credit leaves no trace.
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 30e18);
        assertEq(mark.markedEth, applyRate(30e18, 1.05e18));
        assertEq(_markCursor(), 30e18);

        vm.roll(block.number + 1);
        _reportRate(1.1e18);
        uint32 requestB = _openRequest(user, 20e18); // [30, 50) at rate 1.1

        // the surplus from the earlier report did not follow B into the queue
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).amount, 30e18);

        // the whole 50 LsETH is swept at 1.15, above both cap rates in play -- A's locked 1.05 and B's
        // request rate of 1.10 -- so the cap binds rather than the settlement
        _reportRate(1.15e18);
        _reportWithdraw(50e18, 1.15e18);

        assertEq(_claim(requestA), applyRate(30e18, 1.05e18));
        // B sits entirely in the gap above the mark: paid its own 1.1. Had the clamped-away 70 LsETH
        // carried forward, B would have been paid at 1.05 * 20 or better.
        assertEq(_claim(requestB), applyRate(20e18, 1.1e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C10 — the three-way max in `markStart`
    //
    // markStart = max(lastMarkEnd, settledHeight, rateMarkFloor). Each test below arranges for one of
    // the three to be strictly the largest and asserts the height of the mark that comes out.
    // ─────────────────────────────────────────────────────────────────────────

    /// Scenario: a mark already ends above both the settled height and the floor, and a second delta
    /// is reported.
    /// Expected: `lastMarkEnd` wins, so consecutive reports tile the axis without re-marking demand
    /// that already has a locked rate.
    function testMarkStartUsesLastMarkEndWhenItIsHighest() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        // a 5 LsETH pre-upgrade request pins the floor at 5
        _openRequest(user, 5e18);
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 5e18);

        // 45 LsETH of post-upgrade demand: the axis now runs to 50
        uint32 fresh = _openRequest(user, 45e18);

        // first report marks [5, 15), so the cursor lands at 15
        _reportRate(1.02e18);
        _reportStoppedEarning(applyRate(10e18, 1.02e18));
        assertEq(_markCursor(), 15e18);

        // settle only 10 LsETH, leaving the settled height below the cursor
        _reportWithdraw(10e18, 1.02e18);
        assertEq(_settledHeight(), 10e18);

        // candidates: lastMarkEnd 15, settledHeight 10, floor 5 -- lastMarkEnd is strictly the largest
        _reportRate(1.04e18);
        _reportStoppedEarning(applyRate(20e18, 1.04e18));

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(1);
        assertEq(mark.height, 15e18, "markStart must follow the previous mark's end");
        assertEq(mark.amount, 20e18);
        // contiguous here: nothing was settled past the previous mark, so no gap opens
        assertEq(_markCursor(), 35e18);
        _assertMarkStackWellFormed(fresh);
    }

    /// Scenario: settlement outruns marking -- a withdrawal event prices demand past the end of the
    /// last mark -- and a further delta is reported.
    /// Expected: `settledHeight` wins, opening a permanent gap. The gap is demand settled without ever
    /// being marked, paid at the request rate.
    function testMarkStartUsesSettledHeightWhenItIsHighest() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        // same 5 LsETH pre-upgrade request, so the floor is again 5
        _openRequest(user, 5e18);
        _upgradeToV1_3();
        uint32 fresh = _openRequest(user, 45e18);

        // first report marks [5, 15)
        _reportRate(1.02e18);
        _reportStoppedEarning(applyRate(10e18, 1.02e18));
        assertEq(_markCursor(), 15e18);

        // settle 25 LsETH, pricing [0, 25) and overrunning the mark cursor by 10
        _reportWithdraw(25e18, 1.02e18);
        assertEq(_settledHeight(), 25e18);

        // candidates: lastMarkEnd 15, settledHeight 25, floor 5 -- settledHeight is strictly the largest
        _reportRate(1.04e18);
        _reportStoppedEarning(applyRate(10e18, 1.04e18));

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(1);
        assertEq(mark.height, 25e18, "markStart must skip demand a withdrawal event already priced");
        assertEq(mark.amount, 10e18);
        // the [15, 25) gap is permanent: marks never reach backwards
        assertEq(redeemManager.getRateMarkDetails(0).height + redeemManager.getRateMarkDetails(0).amount, 15e18);
        _assertMarkStackWellFormed(fresh);
    }

    /// Scenario: the launch cutover. The floor is pinned above the settled height at upgrade time and
    /// no mark exists yet, then a delta is reported.
    /// Expected: `rateMarkFloor` wins the max, so marking starts past the entire pre-upgrade queue.
    /// @dev The floor can only win while the stack is empty -- any pushed mark satisfies
    ///      `markStart >= floor` and `amount > 0`, so `lastMarkEnd > floor` from the first mark onward
    ///      -- which is why this branch has no `lastMarkEnd` competitor to arrange.
    function testMarkStartUsesRateMarkFloorWhenItIsHighest() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        // 50 LsETH of pre-upgrade demand pins the floor at 50
        _openRequest(user, 50e18);
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 50e18);

        // settle 20 of it, so the settled height is non-zero but still well below the floor
        _reportWithdraw(20e18, 1e18);
        assertEq(_settledHeight(), 20e18);

        // 30 LsETH of post-upgrade demand: the axis runs to 80
        uint32 fresh = _openRequest(user, 30e18);

        // candidates: lastMarkEnd 0 (stack empty), settledHeight 20, floor 50 -- the floor is largest
        assertEq(_markCursor(), 0);
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(30e18, 1.05e18));

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 50e18, "markStart must start past the pre-upgrade queue");
        assertEq(mark.amount, 30e18);
        assertEq(mark.markedEth, applyRate(30e18, 1.05e18));
        _assertMarkStackWellFormed(fresh);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C14 — stack growth discipline
    // ─────────────────────────────────────────────────────────────────────────

    /// Scenario: seven consecutive `reportStoppedEarning` calls over a queue that grows and settles in
    /// between -- marks that fit whole, marks separated by a settlement gap, marks clamped to the
    /// remaining demand, and reports with nothing left to mark.
    /// Expected: the stack grows by at most one entry per call, stays strictly ascending and disjoint,
    /// and no mark ends above the total LsETH ever requested.
    function testMarkStackGrowsByAtMostOnePerReport() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        uint32 requestA = _openRequest(user, 40e18); // [0, 40); the axis runs to 40
        uint256 count = redeemManager.getRateMarkCount();
        assertEq(count, 0);

        // report 1 -- a whole mark. markStart = max(0, 0, 0) = 0, markable 40, so 10 fits: mark [0, 10).
        _reportRate(1.01e18);
        _reportStoppedEarning(applyRate(10e18, 1.01e18));
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 1 grew by more than one");
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestA);

        // settle 25 LsETH, pushing the settled height past the cursor at 10
        _reportWithdraw(25e18, 1.01e18);

        // report 2 -- a gapped mark. markStart = max(10, 25, 0) = 25: mark [25, 35), leaving [10, 25)
        // permanently unmarked.
        _reportRate(1.02e18);
        _reportStoppedEarning(applyRate(10e18, 1.02e18));
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 2 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(1).height, 25e18);
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestA);

        // report 3 -- a clamped mark. markStart = 35, markable = 40 - 35 = 5, so 20 is cut to 5.
        _reportRate(1.03e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(20e18, 5e18);
        _reportStoppedEarning(applyRate(20e18, 1.03e18));
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 3 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(2).height, 35e18);
        assertEq(redeemManager.getRateMarkDetails(2).amount, 5e18);
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestA);

        // report 4 -- nothing markable. markStart = 40 = totalRequestedHeight, so markable is 0 and the
        // clamp reduces the report to nothing. The stack must not grow: a zero-amount mark would break
        // the strict ordering the predecessor search relies on.
        _reportRate(1.04e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(10e18, 0);
        _reportStoppedEarning(applyRate(10e18, 1.04e18));
        assertEq(redeemManager.getRateMarkCount(), count, "report 4 must not grow the stack");
        _assertMarkStackWellFormed(requestA);

        _reportRate(1.05e18);
        uint32 requestB = _openRequest(user, 30e18); // [40, 70); the axis now runs to 70

        // report 5 -- a whole mark again, now that fresh demand has reopened headroom: mark [40, 55).
        _reportRate(1.06e18);
        _reportStoppedEarning(applyRate(15e18, 1.06e18));
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 5 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(3).height, 40e18);
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestB);

        // report 6 -- a large clamped mark. markStart = 55, markable = 70 - 55 = 15, so 100 is cut to 15.
        _reportRate(1.07e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(100e18, 15e18);
        _reportStoppedEarning(applyRate(100e18, 1.07e18));
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 6 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(4).height, 55e18);
        assertEq(redeemManager.getRateMarkDetails(4).amount, 15e18);
        // the clamp preserves the reported rate
        assertEq(redeemManager.getRateMarkDetails(4).markedEth, applyRate(15e18, 1.07e18));
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestB);

        // report 7 -- saturated again at the top of the axis, so again no growth
        _reportRate(1.08e18);
        _reportStoppedEarning(applyRate(5e18, 1.08e18));
        assertEq(redeemManager.getRateMarkCount(), count, "report 7 must not grow the stack");

        // five marks from seven reports, covering [0,10) [25,35) [35,40) [40,55) [55,70)
        assertEq(redeemManager.getRateMarkCount(), 5);
        assertEq(_markCursor(), 70e18);
        _assertMarkStackWellFormed(requestB);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C15 — markable is measured from the axis, not from outstanding demand
    // ─────────────────────────────────────────────────────────────────────────

    /// Scenario: a withdrawal event settles past the end of the first request, pushing `markStart`
    /// beyond it, while the tail of a later request is still queued. A mark is placed there, then a
    /// delta far larger than the remaining headroom is reported.
    /// Expected: `markable` is `totalRequestedHeight - markStart`, strictly smaller than the
    /// outstanding demand here. Using the demand instead would over-mark by what the first mark covers.
    function testMarkableIsMeasuredFromTotalRequestedHeightNotOutstandingDemand() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        _openRequest(user, 30e18); // A at [0, 30)
        uint32 requestB = _openRequest(user, 40e18); // B at [30, 70); the axis runs to 70
        assertEq(redeemManager.getRedeemDemand(), 70e18);

        // settle 40 LsETH: all of A plus the first 10 of B, so the settled height is past A's end at
        // 30 with 30 LsETH of B still queued behind it
        _reportWithdraw(40e18, 1e18);
        assertEq(_settledHeight(), 40e18);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // first mark: markStart = max(0, 40, 0) = 40, driven entirely by the settled height
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(15e18, 1.05e18));
        assertEq(redeemManager.getRateMarkDetails(0).height, 40e18, "markStart must clear the settled height");
        assertEq(redeemManager.getRateMarkDetails(0).amount, 15e18);
        assertEq(_markCursor(), 55e18);

        // now the discriminating report. markStart = max(55, 40, 0) = 55.
        //   markable from the axis:               70 - 55 = 15  <-- correct
        //   markable from outstanding demand:     30            <-- would double-mark [40, 55)
        assertEq(redeemManager.getRedeemDemand(), 30e18);
        _reportRate(1.08e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(100e18, 15e18);
        _reportStoppedEarning(applyRate(100e18, 1.08e18));

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(1);
        assertEq(mark.height, 55e18);
        assertEq(mark.amount, 15e18, "markable must be measured from the axis, not the outstanding demand");
        // the clamp scaled the eth leg in the same proportion, preserving the 1.08 lock
        assertEq(mark.markedEth, applyRate(15e18, 1.08e18));

        assertEq(_markCursor(), 70e18);
        _assertMarkStackWellFormed(requestB);
    }
}
