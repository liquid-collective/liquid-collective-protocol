//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionReportBase.sol";

/// @title Rate mark placement tests
/// @notice Covers where `reportStoppedEarning` puts a mark, and when it refuses to put one at all.
/// @dev `reportStoppedEarning` places each mark at `max(lastMarkEnd, settledHeight)`, then, when the
///      rate mark floor sits above that, CLIPS the part of the report that falls in
///      `[markStart, floor)` out of the reported amount rather than relocating it -- so a report can
///      be reduced, or discarded entirely, before `markStart` moves up to the floor. What survives is
///      sized at `min(survivingLsETH, totalRequestedHeight - markStart)`.
/// @dev RedeemManager.1.t.sol pins the payout consequences of a mark; this suite pins the placement
///      arithmetic, plus the four early returns that discard a reported delta -- a zero eth leg, a zero
///      LsETH leg, an empty queue, and nothing left after the clamp. Only the last emits an event.
contract RateMarkPlacementTests is RedemptionReportBase {
    /// @dev Asserts that marks are nonempty, ordered, disjoint, and within the request axis.
    /// @param lastRequestId The newest request, whose end position is the top of the axis.
    function _assertMarkStackWellFormed(uint32 lastRequestId) internal {
        RedeemQueueV2.RedeemRequest memory lastRequest = redeemManager.getRedeemRequestDetails(lastRequestId);
        uint256 totalRequestedHeight = lastRequest.height + lastRequest.amount;

        uint256 count = redeemManager.getRateMarkCount();
        uint256 previousEnd = 0;
        for (uint256 idx = 0; idx < count; ++idx) {
            RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(uint32(idx));

            assertGt(mark.amount, 0, "empty mark pushed");
            // a mark may sit in a gap above the previous one, never reach back into it
            assertGe(mark.height, previousEnd, "marks overlap");
            // implied by the two above, but it is what the predecessor search binary-searches on
            if (idx > 0) {
                assertGt(mark.height, previousEnd - 1, "mark heights not strictly ascending");
            }
            previousEnd = mark.height + mark.amount;
            assertLe(previousEnd, totalRequestedHeight, "mark end past total requested height");
        }
    }

    // C7 — degenerate legs

    /// Verifies that a stopped-earning report with a zero ETH leg is discarded silently without
    /// mutating the mark stack.
    function testReportStoppedEarningWithZeroEthLegIsDiscarded() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 30e18);
        assertEq(redeemManager.getRateMarkCount(), 0);

        // 30 LsETH stopped earning, valued at 0 eth
        vm.recordLogs();
        vm.prank(address(river));
        redeemManager.reportStoppedEarning(0, 30e18);

        // the guard fires before the clamp, so not even the exceeded-demand event fires
        _assertRedeemManagerSilent("zero eth leg must make the redeem manager emit nothing");
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(_markCursor(), 0);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // the rejected call leaves the request unmarked, so it is paid at its own 1.0 even though the
        // pool has since risen to 1.05
        _reportRate(1.05e18);
        assertEq(_settleAndClaim(id, 30e18, 1.05e18), applyRate(30e18, 1e18));
        assertEq(redeemManager.getBufferedExceedingEth(), applyRate(30e18, 1.05e18) - applyRate(30e18, 1e18));
    }

    /// Verifies that a report whose LsETH leg rounds to zero is discarded silently and does not
    /// interfere with a later valid report.
    function testReportStoppedEarningWithZeroLsETHLegIsDiscarded() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // at 1.05, 1 wei of principal converts to zero shares
        _reportRate(1.05e18);
        vm.recordLogs();
        _reportStoppedEarning(1);

        _assertRedeemManagerSilent("zero LsETH leg must make the redeem manager emit nothing");
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(_markCursor(), 0);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).height, 0);
        assertEq(redeemManager.getRateMarkDetails(0).amount, 30e18);

        assertEq(_settleAndClaim(id, 30e18, 1.05e18), applyRate(30e18, 1.05e18));
    }

    /// Verifies that clamped mark rescaling uses the smallest reachable denominator safely and floors
    /// the proportional ETH amount.
    function testClampedMarkDivisionOnlyRunsWithADenominatorOfTwoOrMore() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        // exactly 1 wei of markable demand, so the clamp target is 1
        uint32 id = _openRequest(user, 1);

        // 2 wei of principal worth 3 wei: over-reported, so the eth leg is rescaled -- the only path
        // that divides. Asked for loosely because a 1 wei position leaves a supply no fractional rate
        // divides; the conversion it produces is pinned below instead.
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

        // the redeemer is held to the division's result: an event offering 3 wei is clamped to 1
        _reportRate(3e18);
        assertEq(_reportWithdraw(1, 3e18), 3);
        assertEq(_claim(id), 1);
        assertEq(redeemManager.getBufferedExceedingEth(), 2);
    }

    // C8 — empty queue

    /// Verifies that a stopped-earning report on an empty queue is discarded and does not credit
    /// requests opened later.
    function testReportStoppedEarningOnEmptyQueueIsDropped() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        assertEq(redeemManager.getRedeemRequestCount(), 0);

        vm.recordLogs();
        _reportStoppedEarning(applyRate(100e18, 1e18));

        // the guard precedes the clamp, so not even the exceeded-demand event fires despite the whole
        // 100 LsETH being unmarkable
        _assertRedeemManagerSilent("an empty queue must make the redeem manager emit nothing");
        assertEq(redeemManager.getRateMarkCount(), 0);

        uint32 id = _openRequest(user, 30e18);
        assertEq(redeemManager.getRateMarkCount(), 0, "no mark may appear retroactively");

        // settled at 1.05 but paid at its own 1.0: had the dropped delta carried forward, a mark over
        // [0, 30) would have raised this cap
        _reportRate(1.05e18);
        assertEq(_settleAndClaim(id, 30e18, 1.05e18), applyRate(30e18, 1e18));
    }

    // C9 — clamped credit does not carry forward

    /// Verifies that stopped-earning credit above markable demand is discarded rather than carried
    /// forward to a later request.
    function testClampedCreditDoesNotAttachToLaterRequest() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 requestA = _openRequest(user, 30e18); // [0, 30) at rate 1.0

        // only A's 30 LsETH of the 100 is markable
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(100e18, 30e18);
        _reportStoppedEarning(applyRate(100e18, 1.05e18));

        // one mark, sized to the markable demand and priced at the reported rate: the 70 LsETH of
        // clamped-away credit leaves no trace
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 30e18);
        assertEq(mark.markedEth, applyRate(30e18, 1.05e18));
        assertEq(_markCursor(), 30e18);

        vm.roll(block.number + 1);
        _reportRate(1.1e18);
        uint32 requestB = _openRequest(user, 20e18); // [30, 50) at rate 1.1

        // the earlier surplus did not follow B into the queue
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).amount, 30e18);

        // swept at 1.15, above A's locked 1.05 and B's request rate of 1.10
        _reportRate(1.15e18);
        _reportWithdraw(50e18, 1.15e18);

        assertEq(_claim(requestA), applyRate(30e18, 1.05e18));
        // B sits in the gap above the mark, paid its own 1.1: had the clamped-away 70 LsETH carried
        // forward it would have been paid at 1.05 * 20 or better
        assertEq(_claim(requestB), applyRate(20e18, 1.1e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C10 — markStart = max(lastMarkEnd, settledHeight, rateMarkFloor). Each test below makes one of
    // the three strictly the largest and asserts the height of the mark that comes out.
    // ─────────────────────────────────────────────────────────────────────────

    /// Verifies that the previous mark's end determines the next mark start when it is above the
    /// settled height and floor.
    function testMarkStartUsesLastMarkEndWhenItIsHighest() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        _openRequest(user, 5e18);
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 5e18);

        uint32 fresh = _openRequest(user, 45e18);

        // the first report still has the 5 LsETH pre-upgrade request unsettled below the floor, so 5
        // of the 10 reported is clipped away and only the surviving 5 marks [5, 10)
        _reportRate(1.02e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningBelowRateMarkFloor(10e18, 5e18, 5e18);
        _reportStoppedEarning(applyRate(10e18, 1.02e18));
        assertEq(redeemManager.getRateMarkDetails(0).height, 5e18);
        assertEq(redeemManager.getRateMarkDetails(0).amount, 5e18);
        assertEq(_markCursor(), 10e18);

        // settle 8, leaving the settled height below the cursor -- and above the floor, so the clip no
        // longer applies and `lastMarkEnd` is left as the only competitor to beat
        _reportWithdraw(8e18, 1.02e18);
        assertEq(_settledHeight(), 8e18);

        // lastMarkEnd 10, settledHeight 8, floor 5
        _reportRate(1.04e18);
        _reportStoppedEarning(applyRate(20e18, 1.04e18));

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(1);
        assertEq(mark.height, 10e18, "markStart must follow the previous mark's end");
        assertEq(mark.amount, 20e18);
        // nothing was settled past the previous mark, so no gap opens
        assertEq(_markCursor(), 30e18);
        _assertMarkStackWellFormed(fresh);
    }

    /// Verifies that the settled height determines the next mark start when settlement outruns
    /// marking, leaving the skipped range permanently unmarked.
    function testMarkStartUsesSettledHeightWhenItIsHighest() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        // the same 5 LsETH pre-upgrade request, so the floor is again 5
        _openRequest(user, 5e18);
        _upgradeToV1_3();
        uint32 fresh = _openRequest(user, 45e18);

        // 5 of the 10 reported is clipped as below-floor, so this marks [5, 10)
        _reportRate(1.02e18);
        _reportStoppedEarning(applyRate(10e18, 1.02e18));
        assertEq(_markCursor(), 10e18);

        // settle 25, overrunning the mark cursor by 15
        _reportWithdraw(25e18, 1.02e18);
        assertEq(_settledHeight(), 25e18);

        // lastMarkEnd 10, settledHeight 25, floor 5
        _reportRate(1.04e18);
        _reportStoppedEarning(applyRate(10e18, 1.04e18));

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(1);
        assertEq(mark.height, 25e18, "markStart must skip demand a withdrawal event already priced");
        assertEq(mark.amount, 10e18);
        // the [10, 25) gap is permanent, since marks never reach backwards
        assertEq(redeemManager.getRateMarkDetails(0).height + redeemManager.getRateMarkDetails(0).amount, 10e18);
        _assertMarkStackWellFormed(fresh);
    }

    /// Verifies that the rate mark floor determines the first mark start when it is above the settled
    /// height, keeping the pre-upgrade queue unmarked.
    function testMarkStartUsesRateMarkFloorWhenItIsHighest() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        _openRequest(user, 50e18);
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 50e18);

        // settle 20, so the settled height is non-zero but below the floor
        _reportWithdraw(20e18, 1e18);
        assertEq(_settledHeight(), 20e18);

        uint32 fresh = _openRequest(user, 30e18);

        // lastMarkEnd 0 (empty stack), settledHeight 20, floor 50. The report has to outrun the
        // 30 LsETH of still-unsettled pre-upgrade demand in [20, 50) for anything to survive the clip:
        // 50 reported, 30 clipped, 20 marking from the floor.
        assertEq(_markCursor(), 0);
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningBelowRateMarkFloor(50e18, 30e18, 50e18);
        _reportStoppedEarning(applyRate(50e18, 1.05e18));

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 50e18, "markStart must start past the pre-upgrade queue");
        assertEq(mark.amount, 20e18);
        // the clip scaled the eth leg in the same proportion, so the 1.05 lock survives
        assertEq(mark.markedEth, applyRate(20e18, 1.05e18));
        _assertMarkStackWellFormed(fresh);
    }

    // C14 — stack growth discipline

    /// Verifies that each report adds at most one ordered, disjoint mark within the request axis across
    /// whole, gapped, clamped, and saturated cases.
    function testMarkStackGrowsByAtMostOnePerReport() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        uint32 requestA = _openRequest(user, 40e18); // [0, 40)
        uint256 count = redeemManager.getRateMarkCount();
        assertEq(count, 0);

        // report 1 -- whole. markStart = max(0, 0, 0) = 0, markable 40, so 10 fits: mark [0, 10).
        _reportRate(1.01e18);
        _reportStoppedEarning(applyRate(10e18, 1.01e18));
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 1 grew by more than one");
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestA);

        // settle 25, pushing the settled height past the cursor at 10
        _reportWithdraw(25e18, 1.01e18);

        // report 2 -- gapped. markStart = max(10, 25, 0) = 25: mark [25, 35), leaving [10, 25) unmarked.
        _reportRate(1.02e18);
        _reportStoppedEarning(applyRate(10e18, 1.02e18));
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 2 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(1).height, 25e18);
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestA);

        // report 3 -- clamped. markStart = 35, markable = 40 - 35 = 5, so 20 is cut to 5.
        _reportRate(1.03e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(20e18, 5e18);
        _reportStoppedEarning(applyRate(20e18, 1.03e18));
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 3 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(2).height, 35e18);
        assertEq(redeemManager.getRateMarkDetails(2).amount, 5e18);
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestA);

        // report 4 -- nothing markable. markStart = 40 = totalRequestedHeight, so markable is 0. The
        // stack must not grow: a zero-amount mark would break the ordering the predecessor search needs.
        _reportRate(1.04e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(10e18, 0);
        _reportStoppedEarning(applyRate(10e18, 1.04e18));
        assertEq(redeemManager.getRateMarkCount(), count, "report 4 must not grow the stack");
        _assertMarkStackWellFormed(requestA);

        _reportRate(1.05e18);
        uint32 requestB = _openRequest(user, 30e18); // [40, 70)

        // report 5 -- whole again, fresh demand having reopened headroom: mark [40, 55).
        _reportRate(1.06e18);
        _reportStoppedEarning(applyRate(15e18, 1.06e18));
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 5 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(3).height, 40e18);
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestB);

        // report 6 -- clamped hard. markStart = 55, markable = 70 - 55 = 15, so 100 is cut to 15.
        _reportRate(1.07e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(100e18, 15e18);
        _reportStoppedEarning(applyRate(100e18, 1.07e18));
        assertEq(redeemManager.getRateMarkCount(), count + 1, "report 6 grew by more than one");
        assertEq(redeemManager.getRateMarkDetails(4).height, 55e18);
        assertEq(redeemManager.getRateMarkDetails(4).amount, 15e18);
        assertEq(redeemManager.getRateMarkDetails(4).markedEth, applyRate(15e18, 1.07e18));
        count = redeemManager.getRateMarkCount();
        _assertMarkStackWellFormed(requestB);

        // report 7 -- saturated at the top of the axis again
        _reportRate(1.08e18);
        _reportStoppedEarning(applyRate(5e18, 1.08e18));
        assertEq(redeemManager.getRateMarkCount(), count, "report 7 must not grow the stack");

        // five marks from seven reports, covering [0,10) [25,35) [35,40) [40,55) [55,70)
        assertEq(redeemManager.getRateMarkCount(), 5);
        assertEq(_markCursor(), 70e18);
        _assertMarkStackWellFormed(requestB);
    }

    // C15 — markable is measured from the axis, not from outstanding demand

    /// Verifies that markable demand is measured from the request axis rather than outstanding demand,
    /// preventing previously marked ranges from being counted again.
    function testMarkableIsMeasuredFromTotalRequestedHeightNotOutstandingDemand() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        _openRequest(user, 30e18); // A at [0, 30)
        uint32 requestB = _openRequest(user, 40e18); // B at [30, 70)
        assertEq(redeemManager.getRedeemDemand(), 70e18);

        // settle all of A plus the first 10 of B, leaving 30 LsETH of B queued behind it
        _reportWithdraw(40e18, 1e18);
        assertEq(_settledHeight(), 40e18);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // markStart = max(0, 40, 0) = 40, driven by the settled height
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(15e18, 1.05e18));
        assertEq(redeemManager.getRateMarkDetails(0).height, 40e18, "markStart must clear the settled height");
        assertEq(redeemManager.getRateMarkDetails(0).amount, 15e18);
        assertEq(_markCursor(), 55e18);

        // the discriminating report: markStart = max(55, 40, 0) = 55
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
        // the clamp scaled the eth leg in proportion, preserving the 1.08 lock
        assertEq(mark.markedEth, applyRate(15e18, 1.08e18));

        assertEq(_markCursor(), 70e18);
        _assertMarkStackWellFormed(requestB);
    }
}
