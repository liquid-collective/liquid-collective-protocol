//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionReportBase.sol";

/// @title Slice cap geometry tests
/// @notice Covers the ordered walk `_sliceCap` performs over a claimed slice, one geometry per test.
/// @dev The walk splits the slice at every mark boundary, valuing each sub-range at
///      `markedEth / markAmount` where a mark covers it and at `ethAtRequest / lsETHAtRequest`
///      elsewhere. `_findRateMarkAtOrBefore` answers only "the last mark starting at or before this
///      position", not whether it reaches the position -- hence `case 2`, which discards a stale
///      candidate.
/// @dev Every event below is over-funded, slightly, per the cap-binding rule on
///      `RedemptionReportBase`.
contract SliceCapGeometryTests is RedemptionReportBase {
    /// @dev Size of each mark pushed by `_pushRampMarks`.
    uint256 internal constant RAMP_MARK_SIZE = 1e18;
    /// @dev Locked rate of the first mark pushed by `_pushRampMarks`.
    uint256 internal constant RAMP_BASE_RATE = 1e18;
    /// @dev Locked-rate increment between consecutive `_pushRampMarks` marks.
    uint256 internal constant RAMP_RATE_STEP = 1e15;

    /// @dev Pushes `count` contiguous 1 LsETH marks whose locked rate climbs by one step per mark, and
    ///      returns the ETH they are collectively worth. At exactly 1 LsETH per mark the reported eth
    ///      leg is the locked rate, so River's `sharesFromUnderlyingBalance` leg comes back at 1 LsETH
    ///      with no rounding.
    function _pushRampMarks(uint256 count) internal returns (uint256 totalMarkedEth) {
        for (uint256 i = 0; i < count; ++i) {
            uint256 rate = RAMP_BASE_RATE + i * RAMP_RATE_STEP;
            _reportRate(rate);
            uint256 markedEth = applyRate(RAMP_MARK_SIZE, rate);
            _reportStoppedEarning(markedEth);
            totalMarkedEth += markedEth;
        }
    }

    /// @dev Claims `id` against `withdrawalEventId` at unbounded depth, reporting the gas the claim
    ///      itself burned so the cost of the walk stays visible.
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

    /// Verifies that a slice entirely above the last mark uses its request rate and buffers event
    /// funding above that cap.
    ///
    ///     marks   [====== mark0 ======)
    ///     axis    0                  30                  60
    ///     slice                       [===== request B =====)
    function testSliceAboveLastMarkPaysRequestRate() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        _openRequest(user, 30e18); // A occupies [0, 30)
        uint32 b = _openRequest(user, 30e18); // B occupies [30, 60)

        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark0 = redeemManager.getRateMarkDetails(0);
        assertEq(mark0.height + mark0.amount, 30e18);

        _reportWithdraw(30e18, 1.05e18);
        _reportRate(1.08e18);
        _reportWithdraw(30e18, 1.08e18);

        uint256 received = _claim(b);

        // nothing credited at mark0's 1.05: 30 * 1.0
        assertEq(received, 30e18);
        // pro-rata was 30 * 1.08 = 32.4, so 2.4 is confiscated
        assertEq(redeemManager.getBufferedExceedingEth(), 2.4e18);
    }

    /// Verifies that a partial claim starting inside a mark credits only the remaining marked range
    /// without double-counting the consumed prefix.
    ///
    ///     marks   [============== mark0 (40 LsETH @ 1.05) ==============)
    ///     axis    0                15                                  40
    ///     claim 1 [== slice 1 ====)
    ///     claim 2                  [============ slice 2 ==============)
    function testSliceStartingInsideMarkCreditsResidualOnly() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 40e18); // occupies [0, 40)

        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(40e18, 1.05e18));
        RateMarkStack.RateMark memory mark0 = redeemManager.getRateMarkDetails(0);
        assertEq(mark0.height, 0);
        assertEq(mark0.amount, 40e18);
        assertEq(mark0.markedEth, 42e18);

        // both events at 1.08, above mark0's 42/40 == 1.05
        _reportRate(1.08e18);
        _reportWithdraw(15e18, 1.08e18);
        uint256 firstClaim = _claim(id);
        // slice [0, 15) inside mark0: 15 * 42 / 40
        assertEq(firstClaim, 15.75e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).height, 15e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 25e18);

        // 16.2 funded, 15.75 payable
        assertEq(redeemManager.getBufferedExceedingEth(), 0.45e18);
        _reportWithdraw(25e18, 1.08e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        uint256 secondClaim = _claim(id);

        // slice [15, 40): case 3 credits markEnd - cursor = 25 LsETH at 42/40, and nothing else
        assertEq(secondClaim, 26.25e18);
        assertEq(firstClaim + secondClaim, mark0.markedEth);
        // 43.2 funded across the two events, 42 payable; 0.45 of the 1.2 is already back with River
        assertEq(redeemManager.getBufferedExceedingEth(), 0.75e18);
    }

    /// Verifies that a slice ending inside a mark consumes only its overlap, leaving the mark's tail
    /// available to the following request.
    ///
    ///     marks   [================ mark0 (40 LsETH @ 1.05) ============)
    ///     axis    0                 20                                 40
    ///     slice A [== request A ====)
    ///     slice B                    [========= request B =============)
    function testSliceEndingInsideMarkLeavesTailForNextRequest() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 a = _openRequest(user, 20e18); // occupies [0, 20)
        uint32 b = _openRequest(user, 20e18); // occupies [20, 40)

        // one report marks both requests: the pooled-exit case, one exit backing two requests
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(40e18, 1.05e18));
        RateMarkStack.RateMark memory mark0 = redeemManager.getRateMarkDetails(0);
        assertEq(mark0.amount, 40e18);
        assertEq(mark0.markedEth, 42e18);

        // both events at 1.08, above mark0's 42/40 == 1.05
        _reportRate(1.08e18);
        _reportWithdraw(20e18, 1.08e18);
        uint256 receivedA = _claim(a);
        // slice [0, 20): markedAmount would be 40, clipped to remainingAmount = 20 -> 20 * 42 / 40
        assertEq(receivedA, 21e18);
        // 21.6 funded, 21 payable
        assertEq(redeemManager.getBufferedExceedingEth(), 0.6e18);

        _reportWithdraw(20e18, 1.08e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        uint256 receivedB = _claim(b);
        // slice [20, 40): the untouched tail of the very same mark, 20 * 42 / 40
        assertEq(receivedB, 21e18);

        assertEq(receivedA + receivedB, mark0.markedEth);
        // 43.2 funded, 42 payable; half the 1.2 is already back with River
        assertEq(redeemManager.getBufferedExceedingEth(), 0.6e18);
    }

    /// Verifies that a request spanning a permanent gap blends the preceding mark rate, request rate,
    /// and following mark rate across withdrawal-event boundaries.
    ///
    ///     marks   [== mark0 rate 1.05 ==)          [====== mark1 rate 1.10 =====)
    ///     axis    0                20         30                       60
    ///     gap                       [== gap ==)
    ///     request [============ request R (60 LsETH @ 1.00) ============)
    function testSliceSpanningGapBlendsMarkRequestMarkRates() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 60e18); // occupies [0, 60)

        // only the first 20 LsETH of the request is backed by an exit
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(20e18, 1.05e18));
        assertEq(_markCursor(), 20e18);

        // 30 LsETH settled by an event carrying no stopped-earning delta -- so no mark -- pushing the
        // settled height past the mark cursor and opening the gap [20, 30)
        _reportRate(1.08e18);
        _reportWithdraw(30e18, 1.08e18);
        assertEq(_settledHeight(), 30e18);

        // a report can only mark unsettled demand, so mark1 starts at 30, not at 20
        _reportRate(1.1e18);
        _reportStoppedEarning(applyRate(30e18, 1.1e18));
        assertEq(redeemManager.getRateMarkCount(), 2);
        assertEq(redeemManager.getRateMarkDetails(1).height, 30e18);
        assertEq(redeemManager.getRateMarkDetails(1).amount, 30e18);

        _reportRate(1.13e18);
        _reportWithdraw(30e18, 1.13e18);

        // one call walks event 0 then event 1 by recursion
        uint256 received = _claim(id);

        // slice [0, 30) = mark0 then case 1 over the gap: 20 * 1.05 + 10 * 1.00 = 31
        // slice [30, 60) = mark1 in full:                 30 * 1.10             = 33
        assertEq(received, 31e18 + 33e18);
        assertEq(received, 64e18);
        // 32.4 funded at 1.08 plus 33.9 at 1.13 == 66.3, 64 payable
        assertEq(redeemManager.getBufferedExceedingEth(), 66.3e18 - 64e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 2.3e18);
    }

    /// Verifies that a request crossing many marks and gaps sums each segment at the correct rate and
    /// values the remainder above the final mark at the request rate.
    ///
    ///     marks   [m0 rate 1.02)      [== m1 rate 1.04 ==)         [== m2 rate 1.06 ==)    [m3 rate 1.08)
    ///     axis    0       10     20              35       45              65  70        80        100
    ///     gaps             [=====)                [=======)                    [=======)          tail
    ///     request [========================= request R (100 LsETH @ 1.00) ===================)
    function testWalkAcrossFourMarksAndThreeGapsSumsTermByTerm() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 id = _openRequest(user, 100e18); // occupies [0, 100)

        // the pool ramps monotonically, so each sweep is priced a step above the mark before it

        // mark0 = [0, 10) @ 1.02, then settling 20 at 1.03 leaves the gap [10, 20)
        _reportRate(1.02e18);
        _reportStoppedEarning(applyRate(10e18, 1.02e18));
        _reportRate(1.03e18);
        _reportWithdraw(20e18, 1.03e18);

        // mark1 = [20, 35) @ 1.04 at the settled height, then the gap [35, 45)
        _reportRate(1.04e18);
        _reportStoppedEarning(applyRate(15e18, 1.04e18));
        _reportRate(1.05e18);
        _reportWithdraw(25e18, 1.05e18);

        // mark2 = [45, 65) @ 1.06, then the gap [65, 70)
        _reportRate(1.06e18);
        _reportStoppedEarning(applyRate(20e18, 1.06e18));
        _reportRate(1.07e18);
        _reportWithdraw(25e18, 1.07e18);

        // mark3 = [70, 80) @ 1.08, leaving [80, 100) permanently unmarked above the stack
        _reportRate(1.08e18);
        _reportStoppedEarning(applyRate(10e18, 1.08e18));
        _reportRate(1.09e18);
        _reportWithdraw(30e18, 1.09e18);

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

        uint256 markedTerms = applyRate(10e18, 1.02e18) // mark0
            + applyRate(15e18, 1.04e18) // mark1
            + applyRate(20e18, 1.06e18) // mark2
            + applyRate(10e18, 1.08e18); // mark3
        // three gaps of 10, 10 and 5, plus the 20 above the last mark, all at 1.00
        uint256 unmarkedTerms = applyRate(10e18 + 10e18 + 5e18 + 20e18, 1e18);
        assertEq(markedTerms, 57.8e18);
        assertEq(unmarkedTerms, 45e18);
        assertEq(received, markedTerms + unmarkedTerms);
        assertEq(received, 102.8e18);

        // fully claimed, so the loop terminated on every one of the four slices
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
        // 20*1.03 + 25*1.05 + 25*1.07 + 30*1.09 = 106.3 funded, 102.8 payable: all four cap-bound
        assertEq(redeemManager.getBufferedExceedingEth(), 106.3e18 - 102.8e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 3.5e18);
    }

    /// Verifies that a slice starting exactly at a predecessor mark's end receives no stale mark
    /// credit and uses the request rate until the next mark.
    ///
    ///     marks   [== mark0 rate 1.05 ==)          [====== mark1 rate 1.10 =====)
    ///     axis    0                20         30                       60
    ///     slice                     [= slice =)
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

        // one event settles A and the first 10 LsETH of B at 1.12, above every rate the assertions
        // discriminate between: mark0's 1.05, mark1's 1.10 and B's 1.00
        _reportRate(1.12e18);
        _reportWithdraw(30e18, 1.12e18);

        // mark1 opens at 30, leaving the gap [20, 30) -- B's first slice -- permanently unmarked. It
        // locks the pre-report 1.10: nothing requires a mark to sit above the sweep before it.
        _reportRate(1.1e18);
        _reportStoppedEarning(applyRate(30e18, 1.1e18));
        assertEq(redeemManager.getRateMarkDetails(1).height, 30e18);

        uint256 received = _claim(b);

        // slice [20, 30): no credit from mark0 (would be 10.5) and none from mark1 (would be 11)
        assertEq(received, 10e18);
        // pro-rata was 10 * 33.6 / 30 = 11.2
        assertEq(redeemManager.getBufferedExceedingEth(), 1.2e18);
        // partially claimed, with the remainder now at mark1's start
        assertEq(redeemManager.getRedeemRequestDetails(b).height, 30e18);
        assertEq(redeemManager.getRedeemRequestDetails(b).amount, 30e18);
    }

    /// Verifies that a slice with no predecessor mark, whether the stack is empty or starts above the
    /// slice, falls back to its request rate.
    ///
    ///     (b) marks                                     [==== mark0 rate 1.05 ====)
    ///         axis    0        30                      60                     90
    ///         slice   [= A ====)
    function testSliceBelowEveryMarkPaysRequestRate() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        uint32 a = _openRequest(user, 30e18); // occupies [0, 30)
        uint32 b = _openRequest(user, 30e18); // occupies [30, 60)

        // both ranges settle at 1.03, above the 1.00 request rate capping both slices
        _reportRate(1.03e18);
        _reportWithdraw(30e18, 1.03e18);
        _reportWithdraw(30e18, 1.03e18);

        // (a) empty stack. B's slice starts at 30, exercising the `length == 0` guard at a non-zero
        // position rather than at the head of the axis.
        assertEq(redeemManager.getRateMarkCount(), 0);
        assertEq(_claim(b), 30e18);
        // 30.9 pro-rata against a 30 ETH cap
        assertEq(redeemManager.getBufferedExceedingEth(), 0.9e18);

        // (b) a mark pushed above everything already settled, so A's slice is strictly below it. C
        // exists only to give the report markable demand. Opening C is a deposit rather than a report,
        // so B's confiscated 0.9 ETH survives it and the rate move after it is what returns that.
        _openRequest(user, 30e18); // C occupies [60, 90)
        assertEq(redeemManager.getBufferedExceedingEth(), 0.9e18);
        _reportRate(1.05e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).height, 60e18);

        // A's [0, 30) is entirely below mark0's height of 60, so the search bails out before the binary
        // search and case 1 clips 60 - 0 = 60 down to the 30 LsETH in the slice
        assertEq(_claim(a), 30e18);

        // 0.9 confiscated twice, half of it already returned to River by the rate move above
        assertEq(redeemManager.getBufferedExceedingEth(), 0.9e18);
    }

    /// Verifies that a slice starting exactly on a mark height selects that mark rather than its
    /// predecessor, then continues across later marked and unmarked ranges.
    ///
    ///     marks   [m0 )[m1 )[== m2 ==)[== m3 ==)[== m4 ==)
    ///             1.01 1.02   1.03      1.04      1.05
    ///     axis    0    5   10        20        30        40                 50
    ///     slice                       [================ request B ==========)
    function testSliceStartingExactlyOnMarkHeightSelectsThatMark() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);
        _openRequest(user, 20e18); // A occupies [0, 20)
        uint32 b = _openRequest(user, 30e18); // B occupies [20, 50)

        // five contiguous marks, each at its own rate so the terms are distinguishable
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
        // B's start height coincides exactly with m3's, the boundary the search must resolve
        assertEq(redeemManager.getRateMarkDetails(3).height, 20e18);
        assertEq(redeemManager.getRedeemRequestDetails(b).height, 20e18);

        // both events at 1.08, above the 1.04, 1.05 and 1.00 B's slice uses
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
        // 32.4 pro-rata against a 30.9 cap
        assertEq(redeemManager.getBufferedExceedingEth(), 32.4e18 - 30.9e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 1.5e18);
    }

    /// Verifies that a claim can traverse a large mark stack within its gas ceiling and that splitting
    /// across withdrawal events produces the same total payout.
    ///
    ///     marks   [m0)[m1)[m2)...[m199)      each 1 LsETH, rate 1.000, 1.001, ... 1.199
    ///     axis    0   1   2   3        200
    ///     slice   [========== request ======)
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

        // one event over the whole request at 1.25, above the ramp's highest locked rate (m199's 1.199)
        _reportRate(1.25e18);
        _reportWithdraw(200e18, 1.25e18);
        (uint256 received, uint256 gasUsed) = _claimMeasuringGas(single, 0);

        // `emit log_named_uint` rather than `console.log`: this profile builds with via_ir, under which
        // the optimizer may prune console's unused staticcall and the number would vanish
        emit log_named_uint("gas: single-call claim walking 200 rate marks", gasUsed);
        assertEq(received, expected);
        assertEq(redeemManager.getRedeemRequestDetails(single).amount, 0);
        // A regression ceiling, not a production estimate: one Foundry test body is one transaction, so
        // the reports above warmed the mark stack where a live claimant would pay cold-SLOAD prices. It
        // still moves the moment the per-mark work changes. Observed: ~311k for 200 marks.
        assertLt(gasUsed, 1_000_000);

        // ---- phase 2: the same 200-mark geometry, claimed with a bounded depth ----
        _reportRate(1e18);
        uint32 split = _openRequest(user, 200e18); // occupies [200, 400)

        // marks resume at the settled height, so the second ramp mirrors the first
        uint256 expectedSplit = _pushRampMarks(200);
        assertEq(expectedSplit, expected);
        assertEq(redeemManager.getRateMarkCount(), 400);
        assertEq(redeemManager.getRateMarkDetails(200).height, 200e18);

        // eight events of 25 LsETH at 1.25. Every event boundary lands on a mark boundary, so the split
        // introduces no rounding of its own.
        _reportRate(1.25e18);
        for (uint256 i = 0; i < 8; ++i) {
            _reportWithdraw(25e18, 1.25e18);
        }

        // depth 1 handles the starting event plus one recursion: two events per call, four calls, and
        // event ids 1..8 belong to this request
        uint256 splitTotal;
        for (uint32 eventId = 1; eventId <= 7; eventId += 2) {
            splitTotal += _claimWithDepth(split, eventId, 1);
        }

        assertEq(splitTotal, expected);
        assertEq(redeemManager.getRedeemRequestDetails(split).amount, 0);
    }

    /// Verifies that a mark below the request rate re-prices the slice downward, forfeiting later
    /// recovery to the exceeding ETH buffer.
    ///
    ///     rates   request 1.20  ->  mark 1.00  ->  settlement 1.20
    ///     marks   [========= mark0 (30 LsETH @ 1.00) =========)
    ///     axis    0                                          30
    ///     request [============ request R (30 LsETH @ 1.20) ==)
    function testMarkBelowRequestRateRePricesSliceDownwards() external {
        _upgradeToV1_3();
        address user = _generateAllowlistedUser(0);

        _reportRate(1.2e18);
        uint32 id = _openRequest(user, 30e18);
        RedeemRequestAnchor.Anchor memory anchor = redeemManager.getRedeemRequestAnchor(id);
        assertEq(anchor.lsETHAtRequest, 30e18);
        assertEq(anchor.ethAtRequest, 36e18);

        // the pool drops to 1.00 and the principal crosses exit_epoch there, locking 1.00 over the whole
        // request -- below its 1.20
        _reportRate(1e18);
        _reportStoppedEarning(applyRate(30e18, 1e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 30e18);
        assertEq(mark.markedEth, 30e18);
        // cross-multiplied to avoid a truncation in the assertion itself: 30 * 30 < 36 * 30
        assertLt(mark.markedEth * anchor.lsETHAtRequest, anchor.ethAtRequest * mark.amount);

        // full recovery to 1.20 before the sweep, so the event carries the request-time 36 ETH
        _reportRate(1.2e18);
        uint256 withdrawnEth = _reportWithdraw(30e18, 1.2e18);
        assertEq(withdrawnEth, 36e18);

        uint256 received = _claim(id);

        // the mark, not the anchor and not the event, decides the payout
        assertEq(received, 30e18);
        assertEq(received, mark.markedEth);
        assertLt(received, anchor.ethAtRequest);
        assertLt(received, withdrawnEth);
        // the forfeited recovery goes back to the remaining holders
        assertEq(redeemManager.getBufferedExceedingEth(), 6e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
    }

    /// Verifies that a single drawdown mark can re-price every request it spans, including a later
    /// request anchored at a higher rate.
    ///
    ///     marks   [================ mark0 (200 LsETH @ 0.50) ================)
    ///     axis    0                        100                              200
    ///     request [==== A (100 LsETH @ 0.50) ==)[==== B (100 LsETH @ 2.00) ==)
    function testSingleDrawdownMarkRePricesAHigherRateRequest() external {
        _upgradeToV1_3();
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);

        // the pool quadruples between the two requests
        _reportRate(0.5e18);
        uint32 idA = _openRequest(userA, 100e18); // [0, 100), anchored at 50 ETH
        _reportRate(2e18);
        uint32 idB = _openRequest(userB, 100e18); // [100, 200), anchored at 200 ETH
        assertEq(redeemManager.getRedeemRequestAnchor(idA).ethAtRequest, 50e18);
        assertEq(redeemManager.getRedeemRequestAnchor(idB).ethAtRequest, 200e18);
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, 100e18);

        // slashed back to 0.50, where a single pooled exit crosses exit_epoch. markable is the whole
        // axis, so one mark covers both requests at the depressed rate.
        _reportRate(0.5e18);
        _reportStoppedEarning(applyRate(200e18, 0.5e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 200e18);
        assertEq(mark.markedEth, 100e18);

        // full recovery to 2.00 before the sweep: 400 ETH for the 200 LsETH settled, so B's pro-rata
        // share is the full 200 ETH its anchor is worth
        _reportRate(2e18);
        assertEq(_reportWithdraw(200e18, 2e18), 400e18);

        uint256 receivedB = _claim(idB);

        // B is held to the mark's 0.50 over its whole span: 100 * 100 / 200
        assertEq(receivedB, 50e18);
        assertEq(receivedB, (100e18 * mark.markedEth) / mark.amount);
        // a quarter of what B was quoted, and of what the event offered it
        assertEq(receivedB * 4, redeemManager.getRedeemRequestAnchor(idB).ethAtRequest);
        assertEq(redeemManager.getBufferedExceedingEth(), 150e18);

        // A, quoted at the same rate the mark locks, is unaffected
        uint256 receivedA = _claim(idA);
        assertEq(receivedA, 50e18);
        assertEq(receivedA, redeemManager.getRedeemRequestAnchor(idA).ethAtRequest);
        assertEq(redeemManager.getRedeemRequestDetails(idA).amount, 0);
    }
}
