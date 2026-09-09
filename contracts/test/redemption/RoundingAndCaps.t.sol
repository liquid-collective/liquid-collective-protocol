//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionReportBase.sol";

/// @title Rounding, caps and boundary coverage for redemption fulfillment
/// @notice Every payout is `min(pro-rata of the withdrawal event's ETH, _sliceCap(...))`, and every
///         rate in it is an integer division that truncates down. This suite pins the exact wei that
///         falls out of both where they interact: a cap raised above what the protocol received,
///         dust-scale requests and marks, zero-width events, the clamped-mark rescaling, and the
///         exact-fit demand boundary.
contract RedemptionRoundingAndCapsTests is RedemptionReportBase {
    /// Scenario: a mark locks 1.5 over the whole request, then the pool is slashed to 0.6 before the
    /// exit is swept, so the event arrives with far less ETH than the mark promised.
    /// Expected: the payout is the event's pro-rata 18 ETH rather than the 45 ETH cap, the 27 ETH of
    /// mark headroom is wasted, and nothing is diverted to `BufferedExceedingEth` since the cap never
    /// bound.
    /// @dev The complement of `testMarkIsNotAFloorOnSlashing`, which slashes 10% around a 1.05 mark;
    ///      here the headroom exceeds half the cap.
    function testSlashingBetweenMarkAndSweepWastesMarkHeadroomWithoutBuffering() external {
        _upgradeToV1_3();
        address user = _generateAllowlistedUser(0);

        _reportRate(1e18);
        uint32 id = _openRequest(user, 30e18);
        assertEq(redeemManager.getRedeemRequestAnchor(id).ethAtRequest, 30e18);

        // the principal crosses exit_epoch at 1.5, locking 45 ETH over the whole span. reportedLsETH ==
        // markable, so the clamped-mark division is skipped and markedEth is the reported figure.
        _reportRate(1.5e18);
        _reportStoppedEarning(applyRate(30e18, 1.5e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 30e18);
        assertEq(mark.markedEth, 45e18);

        // only then is the pool slashed to 0.6, so the exit is swept at the depressed rate and the
        // event carries 18 ETH for the 30 LsETH it settles -- 27 ETH short of the mark
        _reportRate(0.6e18);
        uint256 withdrawnEth = applyRate(30e18, 0.6e18);
        assertEq(withdrawnEth, 18e18);

        uint256 received = _settleAndClaim(id, 30e18, 0.6e18);

        // the event's pro-rata ETH, (30e18 * 18e18) / 30e18, exact
        assertEq(received, 18e18);
        assertEq(received, withdrawnEth);
        // a ceiling only: the mark did not lift the payout back towards 45 ETH
        assertTrue(received < mark.markedEth);

        // the headroom is wasted rather than carried, and the mark is untouched by the claim
        assertEq(mark.markedEth - received, 27e18);
        assertEq(redeemManager.getRateMarkDetails(0).markedEth, 45e18);

        // the buffer is only fed when the cap binds; here the event was the binding side
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 0);

        // the stale request-time ETH budget keeps its unspent 30 - 18, which post-upgrade bounds nothing
        RedeemQueueV2.RedeemRequest memory request = redeemManager.getRedeemRequestDetails(id);
        assertEq(request.amount, 0);
        assertEq(request.maxRedeemableEth, 12e18);
    }

    /// Scenario: a mark raises every request's cap to 2x its request-time value, above anything the
    /// protocol has received, then one event settles three requests (10 / 20 / 30 LsETH) while carrying
    /// only `61e18 - 1` wei.
    /// Expected: the clamp against the event binds for all three, so the protocol never pays out ETH it
    /// has not received. The payouts sum to `withdrawnEth` minus 1 wei of truncation dust.
    /// @dev The dust: each payout is `(amount_i * withdrawnEth) / 60e18`, three independent floors. At
    ///      `withdrawnEth == 61e18 - 1` the exact shares are W/6, W/3 and W/2, so B's third divides
    ///      while A's and C's halves do not, and the two halves sum to exactly 1 wei.
    ///
    /// @dev FINDING (Informational, fund recovery)
    ///      Claim: pro-rata truncation dust is stranded in the RedeemManager's ETH balance.
    ///      Mechanism: the lost wei is not routed to `BufferedExceedingEth`, so it is neither
    ///        claimable by a redeemer nor pullable by River via `pullExceedingEth`. Asserted below to
    ///        survive a subsequent oracle report.
    ///      Reachability: not from whole-ether request sizes. A reachable full-demand event has
    ///        `withdrawnEth == 60 * rate`, so each payout `size * withdrawnEth / 60e18` divides
    ///        exactly; it needs sizes that are not whole multiples of 1e18. See also the same
    ///        stranding via a zero-width event in `testZeroWidthWithdrawalEventBricksSpanningClaim`,
    ///        which is reachable on the report path.
    ///      Recommendation: route the residual to `BufferedExceedingEth` so River can reclaim it.
    ///
    /// @dev The event is hand-built because it has to be: `_reportWithdrawToRedeemManager` derives the
    ///      pair from a single rate on one of two branches -- `underlyingBalanceFromShares(60e18)`,
    ///      always a multiple of 60 and so never `61e18 - 1`, or
    ///      `sharesFromUnderlyingBalance(withdrawnEth)`, whose rate interval for `amount == 60e18`
    ///      contains no integer. The mark itself is one River computes:
    ///      `sharesFromUnderlyingBalance(120e18) == 60e18` at a pool rate of 2.0.
    function testCapAboveWithdrawalEventStillClampsToEventEth() external {
        _upgradeToV1_3();
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);
        address userC = _generateAllowlistedUser(2);

        // heights 0 / 10 / 30
        _reportRate(1e18);
        uint32 idA = _openRequest(userA, 10e18);
        uint32 idB = _openRequest(userB, 20e18);
        uint32 idC = _openRequest(userC, 30e18);
        assertEq(redeemManager.getRedeemDemand(), 60e18);

        // the whole 60 LsETH is then marked at 2.0, doubling every cap. Nothing has supplied that ETH:
        // a mark is pure entitlement until a withdrawal event arrives.
        _reportRate(2e18);
        _reportStoppedEarning(120e18);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.amount, 60e18);
        assertEq(mark.markedEth, 120e18);
        // per-request caps: 20 / 40 / 60 ETH, each 2x the request-time value
        assertEq((10e18 * mark.markedEth) / mark.amount, 20e18);
        assertEq((20e18 * mark.markedEth) / mark.amount, 40e18);
        assertEq((30e18 * mark.markedEth) / mark.amount, 60e18);

        // one event settles all 60 LsETH carrying 61 ETH minus 1 wei -- far below the 120 ETH of
        // aggregate cap, and chosen so two of the three pro-rata divisions truncate
        uint256 withdrawnEth = 61e18 - 1;
        vm.deal(address(river), address(river).balance + withdrawnEth);
        vm.prank(address(river));
        redeemManager.reportWithdraw{value: withdrawnEth}(60e18);
        assertEq(address(redeemManager).balance, withdrawnEth);

        uint256 receivedA = _claim(idA);
        uint256 receivedB = _claim(idB);
        uint256 receivedC = _claim(idC);

        // the event's pro-rata ETH truncated down, with every cap (20 / 40 / 60) slack
        assertEq(receivedA, (10e18 * withdrawnEth) / 60e18);
        assertEq(receivedB, (20e18 * withdrawnEth) / 60e18);
        assertEq(receivedC, (30e18 * withdrawnEth) / 60e18);
        assertEq(receivedA, 10166666666666666666);
        assertEq(receivedB, 20333333333333333333);
        assertEq(receivedC, 30499999999999999999);
        assertTrue(receivedA < 20e18 && receivedB < 40e18 && receivedC < 60e18);

        // solvency: strictly less paid out than the event supplied, despite caps worth 2x
        uint256 totalPaid = receivedA + receivedB + receivedC;
        assertEq(totalPaid, withdrawnEth - 1);
        assertTrue(totalPaid < withdrawnEth);

        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        // the dust is stranded in the manager's balance, outside the buffer, so the pull every report
        // performs cannot retrieve it
        assertEq(address(redeemManager).balance, 1);
        _reportRate(2e18);
        assertEq(address(redeemManager).balance, 1);
    }

    /// Scenario: the smallest non-degenerate state the fulfillment path can be in -- two 1 wei requests,
    /// a 1 wei mark covering only the first, and one 2 wei-wide event carrying 3 wei of ETH.
    /// Expected: no division by zero -- every denominator is 1 or 2 -- and each division floors as
    /// documented, paying each redeemer 1 wei and leaving the 3rd as dust.
    /// @dev The 1 wei mark exercises `(markedAmount * mark.markedEth) / markAmount` at markAmount == 1,
    ///      and B exercises case 2 (a one-wei mark ending at the slice start) then the
    ///      past-the-last-mark branch.
    /// @dev Every leg is derived from the rate in force -- `sharesFromUnderlyingBalance(2) == 1` at 2.0,
    ///      `underlyingBalanceFromShares(2) == 3` at 1.5 -- so request 1.0, mark 2.0, settlement 1.5 is
    ///      the appreciate-then-slash sequence in which a mark becomes a binding ceiling.
    function testDustScaleRequestAndMarkTruncateAsDocumented() external {
        _upgradeToV1_3();
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);

        _reportRate(1e18);
        uint32 idA = _openRequest(userA, 1);
        uint32 idB = _openRequest(userB, 1);
        assertEq(redeemManager.getRedeemRequestAnchor(idA).lsETHAtRequest, 1);
        assertEq(redeemManager.getRedeemRequestAnchor(idA).ethAtRequest, 1);
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, 1);
        assertEq(redeemManager.getRedeemDemand(), 2);

        // 1 wei of principal, worth 2 wei at 2.0, stops earning: a mark over [0, 1) locked at 2.0.
        // reportedLsETH (1) <= markable (2), so no clamp and no clamped-mark division.
        _reportRate(2e18);
        _reportStoppedEarning(2);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 1);
        assertEq(mark.markedEth, 2);
        assertEq(_markCursor(), 1);

        // slashed back to 1.5, where one event settles both wei of demand carrying
        // `underlyingBalanceFromShares(2) == 3` wei
        _reportRate(1.5e18);
        assertEq(_reportWithdraw(2, 1.5e18), 3);
        assertEq(redeemManager.getRedeemDemand(), 0);

        // A: pro-rata (1 * 3) / 2 == 1, floored from 1.5, against the mark's cap of (1 * 2) / 1 == 2
        uint256 receivedA = _claim(idA);
        assertEq(receivedA, 1);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // B: same pro-rata floor, but its slice starts at height 1 where the mark ends, so case 2
        // discards the mark and the request-time rate gives (1 * 1) / 1 == 1 wei. Cap and event tie.
        uint256 receivedB = _claim(idB);
        assertEq(receivedB, 1);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        assertEq(redeemManager.getRedeemRequestDetails(idA).amount, 0);
        assertEq(redeemManager.getRedeemRequestDetails(idB).amount, 0);

        // the 3rd wei aggregates the two 0.5 wei truncations, left in the manager's balance rather than
        // the buffer, so no one can withdraw it
        assertEq(receivedA + receivedB, 2);
        assertEq(address(redeemManager).balance, 1);
    }

    /// Scenario: a zero-width withdrawal event, `{amount: 0, withdrawnEth: 1}`.
    /// Expected (per design): `_isMatch` can never match one -- its predicate needs `height < height + 0`
    /// -- so no top-level claim reaches the division by `event.amount`, and `resolveRedeemRequests`
    /// stays correct for the surrounding requests.
    ///
    /// @dev FINDING (Medium, availability). Pre-existing, not introduced by the rate-mark work.
    ///      Claim: the design expectation holds only for the top-level match check. A request spanning
    ///        a zero-width event cannot be claimed at the default depth -- the whole
    ///        `claimRedeemRequests` call reverts with Panic(0x12).
    ///      Mechanism: `_claimRedeemRequest` recurses into `withdrawalEventId + 1` without
    ///        re-checking `_isMatch`, so it divides by `event.amount == 0`.
    ///      Reachability: on the real report path, when `BalanceToRedeem` is 1 wei and the pool rate
    ///        is above 1. `LibOracleReporting._reportWithdrawToRedeemManager` (L593-L613) guards on
    ///        `suppliedRedeemManagerDemandInEth > 0` but recomputes the LsETH leg with
    ///        `sharesFromUnderlyingBalance`, which rounds down to 0 while the ETH leg stays non-zero.
    ///        The canonical UX path hits it: `resolveRedeemRequests` returns the first matching event
    ///        and claiming from it with the default depth reverts.
    ///      Not permanently stuck: a caller who knows to can drain the request by claiming with
    ///        `_depth == 0` and re-resolving past the event. Both the revert and the recovery are
    ///        asserted below. The wei that funded the event is stranded either way -- never paid out
    ///        and never routed to `BufferedExceedingEth`.
    ///      Recommendation: re-check `_isMatch` before the recursive step, or skip zero-width events
    ///        in the walk and route their ETH to `BufferedExceedingEth`.
    function testZeroWidthWithdrawalEventBricksSpanningClaim() external {
        _upgradeToV1_3();
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);

        // A spans [0, 20), B spans [20, 30). Total demand 30 LsETH.
        _reportRate(1e18);
        uint32 idA = _openRequest(userA, 20e18);
        uint32 idB = _openRequest(userB, 10e18);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // event 0: [0, 10)
        _reportWithdraw(10e18, 1e18);

        // event 1 is the zero-width one, per the flooring rule in `RedemptionReportBase`. This is the
        // only report here that moves the pool; the next brings it back to 1.0 with no request opened
        // in between, so nothing else sees the excursion.
        _reportWithdrawEth(1, 1.5e18);

        // event 2: [10, 30)
        _reportWithdraw(20e18, 1e18);

        assertEq(redeemManager.getWithdrawalEventCount(), 3);
        WithdrawalStack.WithdrawalEvent memory zeroWidth = redeemManager.getWithdrawalEventDetails(1);
        assertEq(zeroWidth.height, 10e18);
        assertEq(zeroWidth.amount, 0);
        assertEq(zeroWidth.withdrawnEth, 1);
        // it consumed no demand: 30 - 10 - 0 - 20 == 0
        assertEq(redeemManager.getRedeemDemand(), 0);
        assertEq(_settledHeight(), 30e18);

        // resolution is unaffected: B resolves to event 2 rather than event 1, even though event 1 also
        // starts at a height <= 20e18, because `_isMatch` rejects an empty interval at every position
        uint32[] memory both = new uint32[](2);
        both[0] = idA;
        both[1] = idB;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(both);
        assertEq(resolved[0], 0);
        assertEq(resolved[1], 2);

        // claiming A from its resolved event at the default depth fills 10 LsETH at event 0, then
        // recurses into event 1 unconditionally, where `(0 * 1) / 0` panics and reverts the call
        {
            uint32[] memory ids = new uint32[](1);
            ids[0] = idA;
            uint32[] memory eventIds = new uint32[](1);
            eventIds[0] = 0;
            vm.expectRevert(stdError.divisionError);
            redeemManager.claimRedeemRequests(ids, eventIds);
        }

        // recovery step 1: `_depth == 0`, so the recursion never loads event 1
        uint256 firstFill = _claimWithDepth(idA, 0, 0);
        assertEq(firstFill, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(idA).amount, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(idA).height, 10e18);

        // recovery step 2: A re-resolves past the zero-width event to event 2, because
        // `_performDichotomicResolution` tests the last event first and event 2 covers [10e18, 30e18)
        uint32[] memory a = new uint32[](1);
        a[0] = idA;
        assertEq(redeemManager.resolveRedeemRequests(a)[0], 2);
        uint256 secondFill = _claim(idA);
        assertEq(secondFill, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(idA).amount, 0);

        // B claims normally against event 2: (10e18 * 20e18) / 20e18
        assertEq(_claim(idB), 10e18);

        // the wei in the zero-width event can never be paid to anyone: no request matches it, so it is
        // never part of any pro-rata, and it is not buffered either, so no report returns it to River
        assertEq(firstFill + secondFill + 10e18, 30e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 1);
        _reportRate(1e18);
        assertEq(address(redeemManager).balance, 1);
    }

    /// Scenario: a stopped-earning report whose LsETH leg (7 wei) overshoots the markable demand (3
    /// wei), at an eth/LsETH pair (10 / 7) chosen so the clamped-mark rescaling
    /// `(stoppedEarningEth * lsETHToMark) / reportedLsETH` == `(10 * 3) / 7` truncates.
    /// Expected: the locked rate `markedEth / amount` lands strictly below the reported
    /// `stoppedEarningEth / reportedLsETH` -- truncation favours the protocol, never the redeemer.
    /// @dev The other side of `testClampedMarkPreservesReportedRate`, which covers the divisible case:
    ///      an inexact rescaling drops the residual downwards, and the clamped payout shows that
    ///      reaching the redeemer.
    /// @dev Both legs are River's own: at 1.4 `sharesFromUnderlyingBalance(10) == 7` (floored from
    ///      7.14), and at 1.7 the 3 wei of demand is worth `underlyingBalanceFromShares(3) == 5`, so a
    ///      5 wei sweep settles it in full. The reported 10/7 is itself an artifact of the 1.4 rate --
    ///      at dust scale the pair never expresses the rate exactly.
    function testClampedMarkTruncatesLockedRateDownwards() external {
        _upgradeToV1_3();
        address user = _generateAllowlistedUser(0);

        _reportRate(1e18);
        uint32 id = _openRequest(user, 3);

        // 10 wei of principal stops earning at 1.4, valued at 7 wei of LsETH -- a reported rate of
        // 10/7 ~= 1.42857 -- but only 3 wei is markable, so the eth leg is rescaled to
        // (10 * 3) / 7 == 4.2857 -> 4 wei. Asked for loosely because a 3 wei position leaves a supply
        // no fractional rate divides; the conversions the scenario rests on are pinned below instead.
        uint256 reportedEth = 10;
        uint256 reportedLsETH = 7;
        _reportRateLoose(1.4e18);
        assertEq(
            river.sharesFromUnderlyingBalance(reportedEth),
            reportedLsETH,
            "the 10 wei eth leg must be valued at 7 wei of LsETH"
        );
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(reportedLsETH, 3);
        _reportStoppedEarning(reportedEth);

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 3);
        // truncated DOWN from 4.2857 to 4
        assertEq(mark.markedEth, 4);
        assertEq(mark.markedEth, (reportedEth * 3) / reportedLsETH);

        // 4/3 == 1.3333 < 10/7 == 1.42857, cross-multiplied to avoid a second truncation in the
        // assertion itself: 4 * 7 == 28 < 10 * 3 == 30
        assertTrue(mark.markedEth * reportedLsETH < reportedEth * mark.amount);
        // the gap is sub-wei (2/7 of one); the direction is what the test is about
        assertEq(reportedEth * mark.amount - mark.markedEth * reportedLsETH, 2);
        assertTrue(mark.markedEth * reportedLsETH <= reportedEth * mark.amount);

        // at 1.7 the 3 wei of demand is worth 5, so a 5 wei sweep settles it in full and offers more
        // than the locked rate: the cap binds at (3 * 4) / 3 == 4 wei
        assertEq(_reportWithdraw(3, 1.7e18), 5);
        assertEq(river.underlyingBalanceFromShares(3), 5, "the 3 wei of demand must be worth 5 wei at the sweep rate");
        uint256 received = _claim(id);

        assertEq(received, 4);
        // had the rescaling rounded up to 5, the redeemer would have taken the whole event
        assertTrue(received < 5);
        // the withheld wei goes to the remaining holders via the buffer
        assertEq(redeemManager.getBufferedExceedingEth(), 1);
    }

    /// Scenario: the entire LsETH supply queued in one request, then a stopped-earning report whose
    /// LsETH leg River's own conversion truncates to zero, then a genuine full-supply report.
    /// Expected: the dual-nonzero guard absorbs the degenerate pair without reverting or pushing an
    /// empty mark, and the genuine report marks the whole axis through the un-clamped branch.
    /// @dev A dust eth leg is the only reachable way into the zero-leg guard while the pool has shares:
    ///      a zero ETH leg means River never makes the call (LibOracleReporting L392), covered
    ///      defensively in `RateMarkPlacementTests.testReportStoppedEarningWithZeroEthLegIsDiscarded`.
    /// @dev Pins the absence of a mark, not the safety of the trailing
    ///      `(stoppedEarningEth * lsETHToMark) / reportedLsETH` -- guarded by the `lsETHToMark == 0`
    ///      return, never reached here, and bounded in
    ///      `RateMarkPlacementTests.testClampedMarkDivisionOnlyRunsWithADenominatorOfTwoOrMore`.
    function testEntireSupplyQueuedThenDegenerateStoppedEarningReports() external {
        _upgradeToV1_3();
        address user = _generateAllowlistedUser(0);

        // every LsETH bar the ballast is queued in one request, and the ballast holder never redeems
        _reportRate(1e18);
        uint32 id = _openRequest(user, 100e18);
        assertEq(river.totalSupply() - river.balanceOf(ballastHolder), 100e18);
        assertEq(river.balanceOf(address(redeemManager)), 100e18);
        assertEq(redeemManager.getRedeemDemand(), 100e18);

        // a 1 wei delta at 2.0 truncates the LsETH leg to (1 * 1e18) / 2e18 == 0
        _reportRate(2e18);
        _reportStoppedEarning(1);
        assertEq(redeemManager.getRateMarkCount(), 0);

        // a genuine report: the whole 100 LsETH stopped earning, worth 200 ETH at 2.0. reportedLsETH ==
        // markable, so no clamp, no division and no truncation.
        _reportStoppedEarning(200e18);
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 100e18);
        assertEq(mark.markedEth, 200e18);
        assertEq(_markCursor(), 100e18);

        // one event at the marked rate: cap and event tie at 200 ETH, so nothing is confiscated
        uint256 received = _settleAndClaim(id, 100e18, 2e18);
        assertEq(received, 200e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
        assertEq(redeemManager.getRedeemDemand(), 0);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 0);
    }

    /// Scenario: the exact-fit boundary and its two neighbours -- (1) an event whose LsETH leg equals
    /// the outstanding demand to the wei, (2) demand one wei above what the event settles, (3) an event
    /// carrying one wei more ETH than the demand it settles is worth.
    /// Expected: (1) a full fill, `_isMatch` holding at the lower endpoint and rejected at the upper one
    /// since the interval is half-open, with no dust anywhere; (2) a partial fill leaving exactly 1 wei
    /// unsatisfied; (3) the surplus wei confiscated rather than paid, the cap binding one wei below.
    function testExactFitDemandBoundaryAndItsOffByOneNeighbours() external {
        _upgradeToV1_3();
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);
        _reportRate(1e18);

        // ── (1) exact fit: demand == the event's LsETH leg ────────────────────────────────────────
        uint32 idA = _openRequest(userA, 30e18);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        _reportWithdraw(30e18, 1e18);
        // drained to zero by a leg of exactly its own size
        assertEq(redeemManager.getRedeemDemand(), 0);

        // the lower endpoint: the request's height equals the event's
        assertEq(redeemManager.getRedeemRequestDetails(idA).height, redeemManager.getWithdrawalEventDetails(0).height);
        uint32[] memory a = new uint32[](1);
        a[0] = idA;
        assertEq(redeemManager.resolveRedeemRequests(a)[0], 0);

        uint256 receivedA = _claim(idA);
        assertEq(receivedA, 30e18);

        // ...and the upper one: a request opened at height 30e18, exactly where the event ends, does
        // not match it
        uint32 idB = _openRequest(userB, 20e18 + 1);
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, 30e18);
        uint32[] memory b = new uint32[](1);
        b[0] = idB;
        assertEq(redeemManager.resolveRedeemRequests(b)[0], -1);

        // no dust after the exact fit: request and ETH budget drained, buffer and balance both empty
        RedeemQueueV2.RedeemRequest memory requestA = redeemManager.getRedeemRequestDetails(idA);
        assertEq(requestA.amount, 0);
        assertEq(requestA.maxRedeemableEth, 0);
        assertEq(redeemManager.resolveRedeemRequests(a)[0], -3);
        assertEq(redeemManager.getRedeemDemand(), 20e18 + 1);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 0);

        // ── (2) demand one wei ABOVE the event: 20e18 + 1 outstanding, 20e18 settled ──────────────
        _reportWithdraw(20e18, 1e18);
        uint256 receivedB = _claim(idB);

        // capped by the event's width rather than the request's: matching == 20e18, and the cap
        // (20e18 * (20e18+1)) / (20e18+1) == 20e18 divides exactly, so the two tie
        assertEq(receivedB, 20e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // exactly one wei of the request, and of the demand, survives
        RedeemQueueV2.RedeemRequest memory requestB = redeemManager.getRedeemRequestDetails(idB);
        assertEq(requestB.amount, 1);
        assertEq(requestB.height, 50e18);
        assertEq(requestB.maxRedeemableEth, 1);
        assertEq(redeemManager.getRedeemDemand(), 1);
        assertEq(redeemManager.resolveRedeemRequests(b)[0], -1);
        assertEq(address(redeemManager).balance, 0);

        // ── (3) demand one wei below the ETH available: 1 wei of demand, 2 wei of ETH ─────────────
        // the pool has doubled by the sweep, so `underlyingBalanceFromShares(1) == 2` offers 2 wei
        // where the request-time cap allows (1 * (20e18+1)) / (20e18+1) == 1
        _reportRate(2e18);
        _reportWithdraw(1, 2e18);
        assertEq(redeemManager.getWithdrawalEventDetails(2).withdrawnEth, 2);

        uint256 lastWei = _claim(idB);
        // the cap binds one wei below the event, so the surplus is confiscated
        assertEq(lastWei, 1);
        assertEq(redeemManager.getBufferedExceedingEth(), 1);
        assertEq(address(redeemManager).balance, 1);

        // completely drained: no dust in any request or in the demand
        assertEq(redeemManager.getRedeemRequestDetails(idB).amount, 0);
        assertEq(redeemManager.getRedeemDemand(), 0);
        assertEq(receivedA + receivedB + lastWei, 50e18 + 1);
    }

    /// Scenario: `reportWithdraw` called with an LsETH leg one wei above the outstanding demand, then
    /// with a leg exactly equal to it.
    /// Expected: the first reverts `WithdrawalExceedsRedeemDemand(demand + 1, demand)` with both
    /// arguments real, leaving the withdrawal stack and the demand untouched; the second succeeds.
    /// @dev The bound is the solvency guard on the LsETH axis: a wider leg would push an event covering
    ///      positions no request will occupy, and the unchecked `redeemDemand - _lsETHWithdrawable`
    ///      below the check would underflow.
    /// @dev Defensive coverage on the `onlyRiver` entry point, which is why this is the one settlement
    ///      test not going through an oracle report: `_reportWithdrawToRedeemManager` starts from
    ///      `getRedeemDemand()` and only shrinks it, so River cannot present a leg above the demand.
    function testReportWithdrawRevertsOneWeiAboveDemandAndAcceptsExactEquality() external {
        _upgradeToV1_3();
        address user = _generateAllowlistedUser(0);

        _reportRate(1e18);
        _openRequest(user, 30e18);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        vm.deal(address(river), address(river).balance + 60e18 + 2);

        // one wei above the outstanding demand: rejected, both arguments reported exactly
        vm.expectRevert(
            abi.encodeWithSignature("WithdrawalExceedsRedeemDemand(uint256,uint256)", 30e18 + 1, uint256(30e18))
        );
        vm.prank(address(river));
        redeemManager.reportWithdraw{value: 30e18 + 1}(30e18 + 1);

        // nothing recorded and nothing consumed by the rejected call
        assertEq(redeemManager.getWithdrawalEventCount(), 0);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // the boundary is inclusive on the demand side
        vm.prank(address(river));
        redeemManager.reportWithdraw{value: 30e18}(30e18);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory withdrawalEvent = redeemManager.getWithdrawalEventDetails(0);
        assertEq(withdrawalEvent.height, 0);
        assertEq(withdrawalEvent.amount, 30e18);
        assertEq(withdrawalEvent.withdrawnEth, 30e18);
        assertEq(redeemManager.getRedeemDemand(), 0);

        // with the demand now at zero, even a single wei of LsETH is one wei too many
        vm.expectRevert(
            abi.encodeWithSignature("WithdrawalExceedsRedeemDemand(uint256,uint256)", uint256(1), uint256(0))
        );
        vm.prank(address(river));
        redeemManager.reportWithdraw{value: 1}(1);
        assertEq(redeemManager.getWithdrawalEventCount(), 1);
    }
}
