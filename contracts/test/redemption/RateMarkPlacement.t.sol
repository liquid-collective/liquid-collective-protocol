//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionTestBase.sol";

/// @title Rate mark placement tests
/// @notice Covers where `reportStoppedEarning` puts a mark, and when it refuses to put one at all.
/// @dev All queued LsETH forms one ascending cumulative axis. Marks are ascending, disjoint intervals
///      on that axis, but NOT contiguous: the gaps between them are exactly the LsETH that is paid at
///      the request-time rate. `reportStoppedEarning` places each mark at
///      `max(lastMarkEnd, settledHeight, rateMarkFloor)` and sizes it at
///      `min(reportedLsETH, totalRequestedHeight - markStart)`.
///
///      The suite in RedeemManager.1.t.sol pins the payout consequences of a mark. This one pins the
///      placement arithmetic itself, plus the four early-return paths that silently discard a reported
///      delta: a zero eth leg, a zero LsETH leg, an empty queue, and nothing left to mark after the
///      clamp. Only the last of those is observable through an event.
contract RateMarkPlacementTests is RedemptionTestBase {
    /// @dev Walks the whole mark stack and asserts the structural invariants that must hold after every
    ///      single report, whatever the report contained.
    /// @param lastRequestId The id of the newest redeem request, used to recover the total LsETH ever
    ///        requested. A request's end position is invariant across its lifetime -- `height` rises and
    ///        `amount` falls by the same amount as it is claimed -- so the newest request's end is the
    ///        top of the axis.
    function _assertMarkStackWellFormed(uint32 lastRequestId) internal {
        RedeemQueueV2.RedeemRequest memory lastRequest = redeemManager.getRedeemRequestDetails(lastRequestId);
        uint256 totalRequestedHeight = lastRequest.height + lastRequest.amount;

        uint256 count = redeemManager.getRateMarkCount();
        uint256 previousEnd = 0;
        for (uint256 idx = 0; idx < count; ++idx) {
            RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(uint32(idx));

            // an empty mark is never pushed: `lsETHToMark == 0` returns early instead, so a zero-amount
            // entry would mean the stack grew without any credit being recorded
            assertGt(mark.amount, 0, "empty mark pushed");
            // disjoint: this mark may sit in a gap above the previous one, but may never reach back into it
            assertGe(mark.height, previousEnd, "marks overlap");
            // strictly ascending, which follows from the two above but is the property `_findRateMarkAtOrBefore`
            // binary-searches on, so it is asserted directly
            if (idx > 0) {
                assertGt(mark.height, previousEnd - 1, "mark heights not strictly ascending");
            }
            previousEnd = mark.height + mark.amount;
            // the clamp to `totalRequestedHeight - markStart` means no mark may ever describe demand that
            // was never requested
            assertLe(previousEnd, totalRequestedHeight, "mark end past total requested height");
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C7 — degenerate legs
    // ─────────────────────────────────────────────────────────────────────────

    /// Scenario: River reports a stopped-earning delta with a zero ETH leg and a non-zero LsETH leg,
    /// with real markable demand pending.
    /// Expected: the first guard in `reportStoppedEarning` returns immediately. No mark, no event at
    /// all -- not even `StoppedEarningExceededMarkableDemand` -- and the delta is gone for good, because
    /// River has already persisted the cumulative `validatorsStoppedEarningBalance` that produced it.
    function testReportStoppedEarningWithZeroEthLegIsDiscarded() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        // 30 LsETH of demand is pending and fully markable: nothing is settled, no mark exists, floor is 0
        uint32 id = _openRequest(user, 30e18);
        assertEq(redeemManager.getRateMarkCount(), 0);

        // a delta that claims 30 LsETH stopped earning but values it at 0 eth
        vm.recordLogs();
        river.sudoReportStoppedEarningAt(address(redeemManager), 0, 30e18);

        // the call is silent: no ReportedStoppedEarning, and no StoppedEarningExceededMarkableDemand
        // either, since the guard fires before the clamp is ever reached
        assertEq(vm.getRecordedLogs().length, 0, "zero eth leg must emit nothing");
        assertEq(redeemManager.getRateMarkCount(), 0);

        // and the discard is permanent: the 30 LsETH is paid at its request rate of 1.0 even though the
        // pool rose to 1.05, exactly as if the report had never mentioned it
        river.sudoSetRate(1.05e18);
        assertEq(_settleAndClaim(id, 30e18, 1.05e18), applyRate(30e18, 1e18));
        // the appreciation the discarded delta would have credited goes back to remaining holders
        assertEq(redeemManager.getBufferedExceedingEth(), applyRate(30e18, 1.05e18) - applyRate(30e18, 1e18));
    }

    /// Scenario: River reports a non-zero ETH leg with a zero LsETH leg. This is how River's conversion
    /// surfaces on a degenerate pool -- `sharesFromUnderlyingBalance` returns 0 when there are no shares
    /// or no asset balance -- so it is a reachable state, not a fuzz artifact.
    /// Expected: early return at the dual-nonzero guard. No mark, no event, and the report path is not
    /// poisoned for the well-formed delta that follows.
    /// @dev This test does NOT pin the safety of the clamped-mark division, and the guard it exercises is
    ///      not what makes that division safe -- deleting `|| _stoppedEarningLsETH == 0` from
    ///      `reportStoppedEarning` leaves this whole suite green. A zero `reportedLsETH` forces
    ///      `lsETHToMark == 0`, so `lsETHToMark > markable` is never true, the clamp (and with it the
    ///      division) is skipped, and the `lsETHToMark == 0` return fires first. The zero-LsETH leg guard
    ///      is a cheap early-out that saves four SLOADs, nothing more; it is observationally identical to
    ///      its own absence. What actually bounds the denominator is asserted in
    ///      `testClampedMarkDivisionOnlyRunsWithADenominatorOfTwoOrMore` below.
    function testReportStoppedEarningWithZeroLsETHLegIsDiscarded() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // 30 eth of principal stopped earning, but the pool converts it to 0 shares
        vm.recordLogs();
        river.sudoReportStoppedEarningAt(address(redeemManager), 30e18, 0);

        // returns cleanly, records nothing, and leaves the axis exactly as it was
        assertEq(vm.getRecordedLogs().length, 0, "zero LsETH leg must emit nothing");
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(_markCursor(), 0);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // the report path is not poisoned: a well-formed delta immediately after still marks normally
        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).height, 0);
        assertEq(redeemManager.getRateMarkDetails(0).amount, 30e18);

        // and only that second delta is reflected in the payout
        assertEq(_settleAndClaim(id, 30e18, 1.05e18), applyRate(30e18, 1.05e18));
    }

    /// Scenario: the tightest state in which the clamped-mark rescaling
    /// `(_stoppedEarningEth * lsETHToMark) / reportedLsETH` actually executes -- 1 wei of markable demand
    /// against a reported LsETH leg of 2 wei.
    /// Expected: the division runs, with a denominator of 2, and truncates 3/2 down to 1 wei.
    /// @dev This is the test that pins the division's safety, which neither zero-leg test above does.
    ///      The rescaling is reached only from the `lsETHToMark > markable` branch, and only after the
    ///      `lsETHToMark == 0` return has been passed, so at that point
    ///      `reportedLsETH > markable == lsETHToMark >= 1` and the denominator is at least 2 by
    ///      construction -- which is why no reachable state can divide by zero there, with or without the
    ///      zero-LsETH-leg early-out. Asserted at the boundary: a denominator of 2 is the smallest the
    ///      division can ever be handed, since `reportedLsETH == 1` would need `markable == 0` to clamp,
    ///      and that returns at `lsETHToMark == 0` instead.
    function testClampedMarkDivisionOnlyRunsWithADenominatorOfTwoOrMore() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        // exactly 1 wei of markable demand, so `markable == 1` is the clamp target
        uint32 id = _openRequest(user, 1);

        // 2 wei of principal worth 3 wei: over-reported, so the eth leg is rescaled rather than taken
        // verbatim, which is the only path that divides
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(2, 1);
        river.sudoReportStoppedEarningAt(address(redeemManager), 3, 2);

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 1);
        // (3 * 1) / 2 == 1, truncated down from 1.5 in the protocol's favour
        assertEq(mark.markedEth, 1);
        assertEq(mark.markedEth, (uint256(3) * mark.amount) / 2);
        _assertMarkStackWellFormed(id);

        // the mark is real and prices the payout: an event offering 3 wei for the 1 wei of demand is
        // clamped to the locked 1 wei, so the division's result is what the redeemer is actually held to
        vm.deal(address(this), 3);
        river.sudoReportWithdraw{value: 3}(address(redeemManager), 1);
        assertEq(_claim(id), 1);
        assertEq(redeemManager.getBufferedExceedingEth(), 2);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C8 — empty queue
    // ─────────────────────────────────────────────────────────────────────────

    /// Scenario: a well-formed stopped-earning delta lands while the redeem queue is completely empty,
    /// then a request is opened immediately afterwards.
    /// Expected: the `requestCount == 0` guard returns before `totalRequestedHeight` is read, so no mark
    /// is pushed and the delta is dropped. The request that follows gets no retroactive credit and is
    /// paid at its own request rate.
    /// @dev Economically this is fine: nobody was waiting. The credit only exists to compensate demand
    ///      that was sitting in the exit queue while the principal backing it stopped earning, and at the
    ///      moment of the report there was no such demand.
    function testReportStoppedEarningOnEmptyQueueIsDropped() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);

        // nothing has ever been requested
        assertEq(redeemManager.getRedeemRequestCount(), 0);

        // River reports 100 LsETH of principal that stopped earning at a rate of 1.05
        vm.recordLogs();
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(100e18, 1.05e18), 100e18);

        // silent: the empty-queue guard precedes the clamp, so not even the "exceeded markable demand"
        // event fires despite the whole 100 LsETH being unmarkable
        assertEq(vm.getRecordedLogs().length, 0, "empty queue must emit nothing");
        assertEq(redeemManager.getRateMarkCount(), 0);

        // a request opened right after the report -- same rate, same block-adjacent state
        uint32 id = _openRequest(user, 30e18);
        assertEq(redeemManager.getRateMarkCount(), 0, "no mark may appear retroactively");

        // it is paid at 1.0, its own request rate, not at the 1.05 the dropped delta was valued at
        river.sudoSetRate(1.05e18);
        assertEq(_settleAndClaim(id, 30e18, 1.05e18), applyRate(30e18, 1e18));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C9 — clamped credit does not carry forward
    // ─────────────────────────────────────────────────────────────────────────

    /// Scenario: a delta far larger than the pending demand is reported, so most of it is clamped away.
    /// A new request then arrives in the next block.
    /// Expected: the clamped-away portion is dropped, not carried. The new request sits in a mark gap and
    /// is paid at its own request rate; only a fresh delta reported after it was queued could mark it.
    function testClampedCreditDoesNotAttachToLaterRequest() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        // request A: 30 LsETH at rate 1.0, occupying [0, 30) on the axis
        uint32 requestA = _openRequest(user, 30e18);

        // 100 LsETH of principal stopped earning at a rate of 1.05, but only A's 30 LsETH is markable
        river.sudoSetRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(100e18, 30e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(100e18, 1.05e18), 100e18);

        // exactly one mark, sized to the markable demand and priced at the reported rate
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 30e18);
        assertEq(mark.markedEth, applyRate(30e18, 1.05e18));
        // the 70 LsETH of clamped-away credit leaves no trace anywhere
        assertEq(_markCursor(), 30e18);

        // next block, pool has appreciated again: request B for 20 LsETH at rate 1.1, occupying [30, 50)
        vm.roll(block.number + 1);
        river.sudoSetRate(1.1e18);
        uint32 requestB = _openRequest(user, 20e18);

        // no new mark appeared: the surplus from the earlier report did not follow B into the queue
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).amount, 30e18);

        // settle the whole 50 LsETH at a much higher rate so the cap, not the settlement, is what binds
        _reportWithdraw(50e18, 1.3e18);

        // A is covered by the mark: paid the locked 1.05, not the 1.3 the pool reached
        assertEq(_claim(requestA), applyRate(30e18, 1.05e18));
        // B sits above the last mark, entirely in a gap: paid its own request rate of 1.1. Had the
        // clamped-away 70 LsETH carried forward, B would have been paid at 1.05 * 20 or better here.
        assertEq(_claim(requestB), applyRate(20e18, 1.1e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C10 — the three-way max in `markStart`
    //
    // markStart = max(lastMarkEnd, settledHeight, rateMarkFloor). Each test below arranges for one of
    // the three to be strictly the largest and asserts the height of the mark that comes out.
    // ─────────────────────────────────────────────────────────────────────────

    /// Scenario: a mark already ends above both the settled height and the floor, and a second delta is
    /// reported.
    /// Expected: `lastMarkEnd` wins the max. The new mark starts exactly where the previous one ended,
    /// so consecutive reports tile the axis without re-marking demand that already has a locked rate.
    function testMarkStartUsesLastMarkEndWhenItIsHighest() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);

        // a 5 LsETH pre-upgrade request pins the floor at 5
        _openRequest(user, 5e18);
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 5e18);

        // 45 LsETH of post-upgrade demand: the axis now runs to 50
        uint32 fresh = _openRequest(user, 45e18);

        // first report marks [5, 15), so the cursor lands at 15
        river.sudoSetRate(1.02e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.02e18), 10e18);
        assertEq(_markCursor(), 15e18);

        // settle only 10 LsETH, deliberately leaving the settled height BELOW the cursor
        _reportWithdraw(10e18, 1.02e18);
        assertEq(_settledHeight(), 10e18);

        // candidates: lastMarkEnd 15, settledHeight 10, floor 5 -- lastMarkEnd is strictly the largest
        river.sudoSetRate(1.04e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(20e18, 1.04e18), 20e18);

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(1);
        assertEq(mark.height, 15e18, "markStart must follow the previous mark's end");
        assertEq(mark.amount, 20e18);
        // contiguous with the previous mark here: nothing was settled past it, so no gap opens
        assertEq(_markCursor(), 35e18);
        _assertMarkStackWellFormed(fresh);
    }

    /// Scenario: settlement outruns marking -- a withdrawal event prices demand past the end of the last
    /// mark -- and a further delta is reported.
    /// Expected: `settledHeight` wins the max, opening a permanent gap between the two marks. The gap is
    /// the demand that was settled without ever being marked, and it is paid at the request rate.
    function testMarkStartUsesSettledHeightWhenItIsHighest() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);

        // same 5 LsETH pre-upgrade request, so the floor is again 5
        _openRequest(user, 5e18);
        _upgradeToV1_3();
        uint32 fresh = _openRequest(user, 45e18);

        // first report marks [5, 15)
        river.sudoSetRate(1.02e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.02e18), 10e18);
        assertEq(_markCursor(), 15e18);

        // settle 25 LsETH, which prices [0, 25) and so overruns the mark cursor by 10
        _reportWithdraw(25e18, 1.02e18);
        assertEq(_settledHeight(), 25e18);

        // candidates: lastMarkEnd 15, settledHeight 25, floor 5 -- settledHeight is strictly the largest
        river.sudoSetRate(1.04e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.04e18), 10e18);

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(1);
        assertEq(mark.height, 25e18, "markStart must skip demand a withdrawal event already priced");
        assertEq(mark.amount, 10e18);
        // the [15, 25) gap is permanent: marks never reach backwards
        assertEq(redeemManager.getRateMarkDetails(0).height + redeemManager.getRateMarkDetails(0).amount, 15e18);
        _assertMarkStackWellFormed(fresh);
    }

    /// Scenario: the launch cutover. The floor is pinned above the settled height at upgrade time and no
    /// mark exists yet, then a delta is reported.
    /// Expected: `rateMarkFloor` wins the max, so marking starts past the entire pre-upgrade queue.
    /// @dev The floor can only ever win while the stack is empty: any pushed mark satisfies
    ///      `markStart >= floor` and `amount > 0`, so `lastMarkEnd > floor` from the first mark onward.
    ///      That is why this branch has no `lastMarkEnd` competitor to arrange.
    function testMarkStartUsesRateMarkFloorWhenItIsHighest() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);

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
        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(30e18, 1.05e18), 30e18);

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
    /// between -- a mix of marks that fit whole, marks separated by a settlement gap, marks clamped to
    /// the remaining demand, and reports with nothing left to mark at all.
    /// Expected: the stack grows by at most one entry per call and never by more; heights are strictly
    /// ascending; marks never overlap; and no mark ever ends above the total LsETH ever requested.
    function testMarkStackGrowsByAtMostOnePerReport() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);

        // request A: 40 LsETH, occupying [0, 40). The axis runs to 40.
        uint32 requestA = _openRequest(user, 40e18);
        uint256 count = redeemManager.getRateMarkCount();
        assertEq(count, 0);

        // report 1 -- a whole mark. markStart = max(0, 0, 0) = 0, markable 40, so 10 fits: mark [0, 10).
        river.sudoSetRate(1.01e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.01e18), 10e18);
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 1 grew by more than one");
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestA);

        // settle 25 LsETH, pushing the settled height to 25, past the cursor at 10
        _reportWithdraw(25e18, 1.01e18);

        // report 2 -- a gapped mark. markStart = max(10, 25, 0) = 25: mark [25, 35), leaving [10, 25)
        // permanently unmarked.
        river.sudoSetRate(1.02e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.02e18), 10e18);
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 2 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(1).height, 25e18);
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestA);

        // report 3 -- a clamped mark. markStart = 35, markable = 40 - 35 = 5, so 20 is cut to 5.
        river.sudoSetRate(1.03e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(20e18, 5e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(20e18, 1.03e18), 20e18);
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 3 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(2).height, 35e18);
        assertEq(redeemManager.getRateMarkDetails(2).amount, 5e18);
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestA);

        // report 4 -- nothing markable. markStart = 40 = totalRequestedHeight, so markable is 0 and the
        // clamp reduces the report to nothing. The stack must NOT grow: a zero-amount mark would break
        // the strict ordering the predecessor search relies on.
        river.sudoSetRate(1.04e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(10e18, 0);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.04e18), 10e18);
        assertEq(redeemManager.getRateMarkCount(), count, "report 4 must not grow the stack");
        _assertMarkStackWellFormed(requestA);

        // request B: 30 more LsETH, occupying [40, 70). The axis now runs to 70.
        river.sudoSetRate(1.05e18);
        uint32 requestB = _openRequest(user, 30e18);

        // report 5 -- a whole mark again, now that fresh demand has reopened headroom: mark [40, 55).
        river.sudoSetRate(1.06e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(15e18, 1.06e18), 15e18);
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 5 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(3).height, 40e18);
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestB);

        // report 6 -- a large clamped mark. markStart = 55, markable = 70 - 55 = 15, so 100 is cut to 15.
        river.sudoSetRate(1.07e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(100e18, 15e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(100e18, 1.07e18), 100e18);
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 6 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(4).height, 55e18);
        assertEq(redeemManager.getRateMarkDetails(4).amount, 15e18);
        // the clamp preserves the reported rate exactly
        assertEq(redeemManager.getRateMarkDetails(4).markedEth, applyRate(15e18, 1.07e18));
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestB);

        // report 7 -- saturated again at the top of the axis, so again no growth
        river.sudoSetRate(1.08e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(5e18, 1.08e18), 5e18);
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
    /// beyond it, while the tail of a later request is still queued. A mark is placed there, and then a
    /// delta far larger than the remaining headroom is reported.
    /// Expected: `markable` is `totalRequestedHeight - markStart`, which is strictly smaller than the
    /// outstanding redeem demand here. Using the demand instead would over-mark by the amount already
    /// covered by the first mark.
    function testMarkableIsMeasuredFromTotalRequestedHeightNotOutstandingDemand() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);

        // request A: 30 LsETH at [0, 30). Request B: 40 LsETH at [30, 70). The axis runs to 70.
        _openRequest(user, 30e18);
        uint32 requestB = _openRequest(user, 40e18);
        assertEq(redeemManager.getRedeemDemand(), 70e18);

        // settle 40 LsETH: all of A plus the first 10 of B. The settled height is now 40, which is past
        // A's end at 30, and 30 LsETH of B is still queued behind it.
        _reportWithdraw(40e18, 1e18);
        assertEq(_settledHeight(), 40e18);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // first mark: markStart = max(0, 40, 0) = 40, driven entirely by the settled height
        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(15e18, 1.05e18), 15e18);
        assertEq(redeemManager.getRateMarkDetails(0).height, 40e18, "markStart must clear the settled height");
        assertEq(redeemManager.getRateMarkDetails(0).amount, 15e18);
        assertEq(_markCursor(), 55e18);

        // now the discriminating report. markStart = max(55, 40, 0) = 55.
        //   markable from the axis:               70 - 55 = 15  <-- correct
        //   markable from outstanding demand:     30            <-- would double-mark [40, 55)
        assertEq(redeemManager.getRedeemDemand(), 30e18);
        river.sudoSetRate(1.08e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(100e18, 15e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(100e18, 1.08e18), 100e18);

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(1);
        assertEq(mark.height, 55e18);
        assertEq(mark.amount, 15e18, "markable must be measured from the axis, not the outstanding demand");
        // and the clamp scaled the eth leg in the same proportion, preserving the 1.08 lock
        assertEq(mark.markedEth, applyRate(15e18, 1.08e18));

        // the stack stops exactly at the top of the axis
        assertEq(_markCursor(), 70e18);
        _assertMarkStackWellFormed(requestB);
    }
}
