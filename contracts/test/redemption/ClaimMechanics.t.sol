//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionReportBase.sol";

/// @title Redemption claim mechanics
/// @notice Covers the positional side of redemption fulfillment: how requests, withdrawal events and
///         rate marks line up against each other during a claim. See `RedemptionReportBase` for the
///         axis model.
/// @dev RedeemManager.1.t.sol pins the one-request/one-mark cases; this suite exercises the
///      misalignment -- a mark stopping between two requests, a mark ending inside one, a request
///      created after a mark was taken, resolution across a long and partly degenerate withdrawal
///      stack, and a claim walk split by `_depth`.
contract RedemptionClaimMechanicsTests is RedemptionReportBase {
    // F1 — one withdrawal event, two requests, one mark covering only the first

    /// Scenario: two 30 LsETH requests opened at 1.00, settled by one 60 LsETH event funded at 1.05,
    /// with a single mark covering [0, 30) -- exactly A -- and stopping short of B.
    /// Expected: A paid at the marked 1.05 (31.5 ETH) and B at its own 1.00 (30 ETH) out of the same
    /// event's 63 ETH, with the 1.5 ETH above B's cap confiscated.
    /// @dev Marks are positional and an event's ETH is fungible: the event does not know which of its
    ///      63 ETH came from an exit and which from the deposit buffer, and does not need to.
    function testOneEventTwoRequestsMarkCoversFirstOnly() external {
        address userA = _generateAllowlistedUser(1);
        address userB = _generateAllowlistedUser(2);

        _reportRate(1e18);
        uint32 idA = _openRequest(userA, 30e18); // occupies [0, 30) on the axis
        uint32 idB = _openRequest(userB, 30e18); // occupies [30, 60)
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, 30e18);

        // only the FIRST 30 LsETH of the queue stopped earning, at a pool rate of 1.05
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(30e18, 1.05e18));

        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 30e18);
        assertEq(mark.markedEth, applyRate(30e18, 1.05e18)); // 31.5 ETH
        assertEq(_markCursor(), 30e18);

        uint256 withdrawnEth = _reportWithdraw(60e18, 1.05e18);
        assertEq(withdrawnEth, 63e18);
        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(_settledHeight(), 60e18);

        // A: pro-rata 31.5 against a cap of 30 * 31.5 / 30 == 31.5, so neither binds
        assertEq(_claim(idA), 31.5e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // B: the same pro-rata share, but its slice sits above the mark, so the cap is its own 1.00
        assertEq(_claim(idB), 30e18);

        assertEq(redeemManager.getBufferedExceedingEth(), 1.5e18);
        assertEq(address(redeemManager).balance, 1.5e18);
    }

    /// Scenario: the same two requests and single 60 LsETH event, but the mark now covers [0, 40),
    /// crossing the A/B boundary at 30 and dying 10 LsETH into B.
    /// Expected: A fully marked at 31.5 ETH; B a blend of 10 at the mark's 1.05 and 20 at its own 1.00,
    /// so 30.5 ETH.
    /// @dev Exercises case 3 -> past-the-last-mark inside `_sliceCap`, splitting B's slice at the end of
    ///      a mark that started under a different request -- which no other test does.
    function testOneEventTwoRequestsMarkStraddlesTheBoundary() external {
        address userA = _generateAllowlistedUser(1);
        address userB = _generateAllowlistedUser(2);

        _reportRate(1e18);
        uint32 idA = _openRequest(userA, 30e18); // [0, 30)
        uint32 idB = _openRequest(userB, 30e18); // [30, 60)

        // 40 LsETH stopped earning at 1.05: all of A and the first third of B
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(40e18, 1.05e18));

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 40e18);
        assertEq(mark.markedEth, 42e18); // 40 LsETH * 1.05
        assertEq(_markCursor(), 40e18);

        uint256 withdrawnEth = _reportWithdraw(60e18, 1.05e18);
        assertEq(withdrawnEth, 63e18);

        // A: fully inside the mark, so its cap of 30 * 42 / 40 == 31.5 ties its pro-rata share
        assertEq(_claim(idA), 31.5e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // B: [30, 40) is marked -> 10 * 42 / 40 = 10.5 ETH; [40, 60) is gap -> 20 * 1.00 = 20 ETH
        uint256 markedLeg = 10.5e18;
        uint256 unmarkedLeg = 20e18;
        assertEq(_claim(idB), markedLeg + unmarkedLeg); // 30.5 ETH
        // genuinely a blend: above the pure request rate and below the pure mark rate, so neither
        // branch alone could produce this number
        assertTrue(markedLeg + unmarkedLeg > applyRate(30e18, 1e18));
        assertTrue(markedLeg + unmarkedLeg < applyRate(30e18, 1.05e18));

        // 63 ETH in, 31.5 + 30.5 = 62 ETH out
        assertEq(redeemManager.getBufferedExceedingEth(), 1e18);
    }

    // F5 — claim ordering across requests

    /// Scenario: three requests opened at 1.00 / 1.02 / 1.04, a single mark covering [0, 15) (all of A
    /// and half of B), and one event settling all 30 LsETH at 1.10 -- run twice, in queue order and
    /// youngest-first.
    /// Expected: identical payouts in both runs.
    /// @dev Order cannot matter because a request's position is fixed by its predecessors and never
    ///      touched by a claim on another request -- `_saveRedeemRequest` writes only the id it was
    ///      given -- and marks and events are addressed by absolute position rather than by "the next
    ///      unclaimed one", so the three claims read three disjoint intervals.
    function testClaimOrderAcrossRequestsDoesNotAffectPayouts() external {
        uint256 snapshotId = _snapshotState();

        (uint256 aInOrder, uint256 bInOrder, uint256 cInOrder, uint256 exceedingInOrder) =
            _runThreeRequestScenario(false);

        assertTrue(_revertToState(snapshotId));

        (uint256 aReversed, uint256 bReversed, uint256 cReversed, uint256 exceedingReversed) =
            _runThreeRequestScenario(true);

        assertEq(aReversed, aInOrder);
        assertEq(bReversed, bInOrder);
        assertEq(cReversed, cInOrder);
        assertEq(exceedingReversed, exceedingInOrder);

        // pinned absolutely too, so this cannot pass by both runs being wrong the same way:
        // A is entirely marked         -> 10 * 15.9 / 15              = 10.6 ETH
        // B straddles the mark's end   -> 5 * 15.9 / 15 + 5 * 1.02    = 5.3 + 5.1 = 10.4 ETH
        // C is entirely above the mark -> 10 * 1.04                   = 10.4 ETH
        assertEq(aInOrder, 10.6e18);
        assertEq(bInOrder, 10.4e18);
        assertEq(cInOrder, 10.4e18);
        // 33 ETH settled, 31.4 ETH paid
        assertEq(exceedingInOrder, 1.6e18);
    }

    /// @dev Builds the scenario and claims it in queue order or youngest-first, returning the
    ///      per-recipient payouts.
    function _runThreeRequestScenario(bool _youngestFirst)
        internal
        returns (uint256 receivedA, uint256 receivedB, uint256 receivedC, uint256 exceeding)
    {
        address userA = _generateAllowlistedUser(1);
        address userB = _generateAllowlistedUser(2);
        address userC = _generateAllowlistedUser(3);

        // three different pool rates, so each request has a distinct request rate
        _reportRate(1e18);
        uint32 idA = _openRequest(userA, 10e18); // [0, 10), anchored at 10.0 ETH
        _reportRate(1.02e18);
        uint32 idB = _openRequest(userB, 10e18); // [10, 20), anchored at 10.2 ETH
        _reportRate(1.04e18);
        uint32 idC = _openRequest(userC, 10e18); // [20, 30), anchored at 10.4 ETH

        // 15 LsETH stops earning at 1.06: all of A and the lower half of B
        _reportRate(1.06e18);
        _reportStoppedEarning(applyRate(15e18, 1.06e18));
        assertEq(redeemManager.getRateMarkDetails(0).amount, 15e18);
        assertEq(redeemManager.getRateMarkDetails(0).markedEth, 15.9e18);

        // one event over the whole queue at 1.10, above the mark's 1.06 and all three request rates
        _reportRate(1.1e18);
        assertEq(_reportWithdraw(30e18, 1.1e18), 33e18);

        uint32[] memory ids = new uint32[](3);
        if (_youngestFirst) {
            ids[0] = idC;
            ids[1] = idB;
            ids[2] = idA;
        } else {
            ids[0] = idA;
            ids[1] = idB;
            ids[2] = idC;
        }

        // one batched call, so the runs differ only in the order of the entries
        uint32[] memory eventIds = new uint32[](3);
        redeemManager.claimRedeemRequests(ids, eventIds);

        return (userA.balance, userB.balance, userC.balance, redeemManager.getBufferedExceedingEth());
    }

    // F6 — a request created after a mark was taken

    /// Scenario: A opened at 1.00 and marked at 1.05, and only then B opened at 1.08, both settled by
    /// one event funded at 1.10.
    /// Expected: B's height sits at the mark's end, so no part of it is covered -- B is paid at its own
    /// 1.08 (32.4 ETH), A keeps the whole mark (31.5 ETH), and opening B mutates nothing.
    /// @dev The three rates all differ so B's payout identifies which was used: 1.05 would mean B stole
    ///      A's mark, 1.10 that the cap was ignored.
    function testRequestOpenedAfterMarkIsUnaffectedByIt() external {
        address userA = _generateAllowlistedUser(1);
        address userB = _generateAllowlistedUser(2);

        _reportRate(1e18);
        uint32 idA = _openRequest(userA, 30e18); // [0, 30) anchored at 30 ETH

        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        RateMarkStack.RateMark memory markBefore = redeemManager.getRateMarkDetails(0);
        assertEq(markBefore.height, 0);
        assertEq(markBefore.amount, 30e18);
        assertEq(markBefore.markedEth, 31.5e18);

        // only now does B join, at a higher pool rate
        _reportRate(1.08e18);
        uint32 idB = _openRequest(userB, 30e18); // [30, 60) anchored at 32.4 ETH
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, 30e18);
        assertEq(redeemManager.getRedeemRequestDetails(idB).maxRedeemableEth, 32.4e18);

        RateMarkStack.RateMark memory markAfter = redeemManager.getRateMarkDetails(0);
        assertEq(markAfter.height, markBefore.height);
        assertEq(markAfter.amount, markBefore.amount);
        assertEq(markAfter.markedEth, markBefore.markedEth);
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(_markCursor(), 30e18);
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, _markCursor());

        // one event at 1.10, above A's mark at 1.05 and B's request rate of 1.08
        _reportRate(1.1e18);
        assertEq(_reportWithdraw(60e18, 1.1e18), 66e18);

        // A: pro-rata 33 clamped to the mark -> 31.5, so 1.5 confiscated
        assertEq(_claim(idA), 31.5e18);
        // B: pro-rata 33 clamped to its own request rate -> 32.4, so 0.6 confiscated
        assertEq(_claim(idB), 32.4e18);

        RateMarkStack.RateMark memory markFinal = redeemManager.getRateMarkDetails(0);
        assertEq(markFinal.height, 0);
        assertEq(markFinal.amount, 30e18);
        assertEq(markFinal.markedEth, 31.5e18);

        assertEq(redeemManager.getBufferedExceedingEth(), 2.1e18); // 1.5 + 0.6
    }

    // F8 — resolution across a long, partly degenerate withdrawal stack

    /// Scenario: 9 requests and 12 abutting withdrawal events, event 3 zero-width, some requests
    /// needing two events and some sharing one, and the last request never settled.
    /// Expected: `resolveRedeemRequests` returns the right event for the head, middle and tail of the
    /// queue and skips the zero-width one; -1 unsettled, -2 nonexistent, -3 claimed. Every resolved id
    /// then claims successfully, bar the request straddling the zero-width event.
    /// @dev That revert is the zero-width finding, stated in full on
    ///      `RedemptionRoundingAndCapsTests.testZeroWidthWithdrawalEventBricksSpanningClaim`:
    ///      resolution steps over the event correctly, but `_claimRedeemRequest` recurses into it
    ///      without re-checking `_isMatch` and divides by `amount == 0`. The two-step recovery is
    ///      exercised below.
    function testResolveAcrossManyWithdrawalEventsIncludingZeroWidth() external {
        address user = _generateAllowlistedUser(1);

        // everything at 1.00, so a payout equals its LsETH size and only positions matter
        _reportRate(1e18);

        // uneven sizes, so requests and events do not line up one-to-one
        uint32 r0 = _openRequest(user, 10e18); // [0, 10)  -- head, spans two events
        uint32 r1 = _openRequest(user, 15e18); // [10, 25) -- straddles the zero-width event
        uint32 r2 = _openRequest(user, 5e18); //  [25, 30)
        uint32 r3 = _openRequest(user, 10e18); // [30, 40)
        uint32 r4 = _openRequest(user, 10e18); // [40, 50) -- middle
        uint32 r5 = _openRequest(user, 10e18); // [50, 60) -- spans two events
        uint32 r6 = _openRequest(user, 10e18); // [60, 70)
        uint32 r7 = _openRequest(user, 10e18); // [70, 80) -- tail of the settled range, spans two events
        uint32 r8 = _openRequest(user, 10e18); // [80, 90) -- never settled
        assertEq(redeemManager.getRedeemDemand(), 90e18);

        // 12 withdrawal events settling the first 80 LsETH; #3 is the zero-width one
        _reportWithdraw(5e18, 1e18); //  0: [0, 5)
        _reportWithdraw(5e18, 1e18); //  1: [5, 10)
        _reportWithdraw(10e18, 1e18); // 2: [10, 20)
        // 3: [20, 20) -- zero LsETH but one wei of ETH, per the flooring rule in
        // `RedemptionReportBase`. The one report here that moves the pool; the next brings it back to
        // 1.0 with no request opened in between.
        _reportWithdrawEth(1, 1.5e18);
        _reportWithdraw(10e18, 1e18); // 4:  [20, 30)
        _reportWithdraw(10e18, 1e18); // 5:  [30, 40)
        _reportWithdraw(10e18, 1e18); // 6:  [40, 50)
        _reportWithdraw(5e18, 1e18); //  7:  [50, 55)
        _reportWithdraw(5e18, 1e18); //  8:  [55, 60)
        _reportWithdraw(10e18, 1e18); // 9:  [60, 70)
        _reportWithdraw(5e18, 1e18); //  10: [70, 75)
        _reportWithdraw(5e18, 1e18); //  11: [75, 80)

        assertEq(redeemManager.getWithdrawalEventCount(), 12);
        assertEq(_settledHeight(), 80e18);
        assertEq(redeemManager.getWithdrawalEventDetails(3).amount, 0);
        assertEq(redeemManager.getWithdrawalEventDetails(3).height, 20e18);
        // abutting, on the pair around the zero-width event
        assertEq(
            redeemManager.getWithdrawalEventDetails(2).height + redeemManager.getWithdrawalEventDetails(2).amount,
            redeemManager.getWithdrawalEventDetails(3).height
        );
        assertEq(redeemManager.getWithdrawalEventDetails(3).height, redeemManager.getWithdrawalEventDetails(4).height);

        // one batch, plus a nonexistent id
        uint32[] memory probe = new uint32[](10);
        probe[0] = r0;
        probe[1] = r1;
        probe[2] = r2;
        probe[3] = r3;
        probe[4] = r4;
        probe[5] = r5;
        probe[6] = r6;
        probe[7] = r7;
        probe[8] = r8;
        probe[9] = 99; // never created
        int64[] memory resolved = redeemManager.resolveRedeemRequests(probe);

        assertEq(resolved[0], 0); // head of the queue -> the first event
        assertEq(resolved[1], 2); // starts at 10, inside event 2
        // starts at 25, which event 3 cannot match -- `_isMatch` needs height < height + amount --
        // so the search steps over it to event 4
        assertEq(resolved[2], 4);
        assertEq(resolved[3], 5);
        assertEq(resolved[4], 6); // middle of the queue
        assertEq(resolved[5], 7);
        assertEq(resolved[6], 9);
        assertEq(resolved[7], 10); // tail of the settled range
        assertEq(resolved[8], -1); // RESOLVE_UNSATISFIED: height 80 == settled height, nothing covers it
        assertEq(resolved[9], -2); // RESOLVE_OUT_OF_BOUNDS

        // r0 walks events 0 and 1 (5 + 5)
        assertEq(_claim(r0), 10e18);
        // fully claimed, so the id now resolves to RESOLVE_FULLY_CLAIMED
        uint32[] memory one = new uint32[](1);
        one[0] = r0;
        assertEq(redeemManager.resolveRedeemRequests(one)[0], -3);

        // r1 straddles the zero-width event: the resolved id is right, but the full-depth walk steps
        // from event 2 onto event 3 and divides zero by zero
        {
            uint32[] memory ids = new uint32[](1);
            ids[0] = r1;
            uint32[] memory eventIds = new uint32[](1);
            eventIds[0] = 2;
            vm.expectRevert(stdError.divisionError);
            redeemManager.claimRedeemRequests(ids, eventIds);
        }
        // recovery: stop before the zero-width event...
        assertEq(_claimWithDepth(r1, 2, 0), 10e18);
        // ...then re-resolve, the residual now starting at 20
        one[0] = r1;
        assertEq(redeemManager.resolveRedeemRequests(one)[0], 4);
        assertEq(_claim(r1), 5e18);

        // the rest claim straight through their resolved ids
        assertEq(_claim(r2), 5e18); // partial slice of event 4
        assertEq(_claim(r3), 10e18);
        assertEq(_claim(r4), 10e18);
        assertEq(_claim(r5), 10e18); // walks events 7 and 8
        assertEq(_claim(r6), 10e18);
        assertEq(_claim(r7), 10e18); // walks events 10 and 11

        // every settled LsETH paid at 1:1, so nothing was capped
        assertEq(user.balance, 80e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        // bar the wei funding the zero-width event: not paid, not counted as exceeding
        assertEq(address(redeemManager).balance, 1);

        one[0] = r8;
        assertEq(redeemManager.resolveRedeemRequests(one)[0], -1);
    }

    // F9 — the residual auto-assigned forward

    /// Scenario: one 30 LsETH request at 1.00 settled by three consecutive 10 LsETH events funded at
    /// 1.05, 0.95 and 1.10, claimed once at full depth and then -- after reverting -- three times at
    /// `depth = 0`.
    /// Expected: the three partial payouts (10 + 9.5 + 10) sum to exactly the single-call payout, with
    /// `height + amount == 30e18` after every one.
    /// @dev Nothing tells a `depth = 0` claim where the last one stopped. The residual finds the next
    ///      event because `_claimRedeemRequest` raises `height` by exactly what it lowered `amount` by
    ///      and the withdrawal stack is contiguous, so the new height is the next event's.
    function testResidualAutoAssignsForwardAcrossDepthZeroClaims() external {
        address user = _generateAllowlistedUser(1);

        _reportRate(1e18);
        uint32 id = _openRequest(user, 30e18); // [0, 30), anchored at 30 ETH -> cap of 1.00 per LsETH

        // three settlement rates -- above the cap, below, above -- each swept at the live pool rate
        _reportRate(1.05e18);
        assertEq(_reportWithdraw(10e18, 1.05e18), 10.5e18); // event 0, [0, 10)
        _reportRate(0.95e18);
        assertEq(_reportWithdraw(10e18, 0.95e18), 9.5e18); //  event 1, [10, 20)
        _reportRate(1.1e18);
        assertEq(_reportWithdraw(10e18, 1.1e18), 11e18); //    event 2, [20, 30)

        // baseline: one uninterrupted call
        uint256 snapshotId = _snapshotState();
        uint256 singleCallPayout = _claim(id);
        assertEq(singleCallPayout, 29.5e18); // 10 (capped) + 9.5 (uncapped) + 10 (capped)
        // 31 settled, 29.5 paid: 0.5 confiscated on event 0, none on event 1, 1.0 on event 2
        assertEq(redeemManager.getBufferedExceedingEth(), 1.5e18);
        assertTrue(_revertToState(snapshotId));

        // and now in three bites
        RedeemQueueV2.RedeemRequest memory request = redeemManager.getRedeemRequestDetails(id);
        assertEq(request.height + request.amount, 30e18);

        // event 0 carries 10.5 against a 10 ETH cap
        uint256 first = _claimWithDepth(id, 0, 0);
        assertEq(first, 10e18);
        request = redeemManager.getRedeemRequestDetails(id);
        assertEq(request.height, 10e18);
        assertEq(request.amount, 20e18);
        assertEq(request.height + request.amount, 30e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0.5e18);

        // event 1 settled below the request rate, so the cap does not bind and the redeemer eats it
        uint256 second = _claimWithDepth(id, 1, 0);
        assertEq(second, 9.5e18);
        request = redeemManager.getRedeemRequestDetails(id);
        assertEq(request.height, 20e18);
        assertEq(request.amount, 10e18);
        assertEq(request.height + request.amount, 30e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0.5e18); // unchanged

        // event 2 carries 11 against the same cap
        uint256 third = _claimWithDepth(id, 2, 0);
        assertEq(third, 10e18);
        request = redeemManager.getRedeemRequestDetails(id);
        assertEq(request.height, 30e18);
        assertEq(request.amount, 0);
        assertEq(request.height + request.amount, 30e18); // holds even fully claimed
        assertEq(redeemManager.getBufferedExceedingEth(), 1.5e18);

        // splitting the walk changes nothing for the redeemer or the pool
        assertEq(first + second + third, singleCallPayout);
        assertEq(user.balance, 29.5e18);
    }

    // F10 — one claim spanning a deposit-funded event and an exit-funded event

    /// Scenario: one 20 LsETH request at 1.00. Event 0 settles its first half with no mark over that
    /// range (funded out of the deposit buffer); a mark at 1.05 is then pushed over the second half and
    /// event 1 settles it (funded by an exit). Claimed in one call spanning both.
    /// Expected: the request rate over the first slice (10 ETH) and the mark rate over the second
    /// (10.5 ETH), for 20.5 total, with one `SatisfiedRedeemRequest` per event in order and a single
    /// aggregate `ClaimedRedeemRequest`.
    /// @dev The mixed-funding case the gap semantics exist for: both events are funded at the same 1.05
    ///      and are indistinguishable as ETH, so only the presence of a mark separates the payouts.
    function testClaimSpanningUnmarkedThenMarkedEventsBlendsAndEmitsPerEvent() external {
        address user = _generateAllowlistedUser(1);

        _reportRate(1e18);
        uint32 id = _openRequest(user, 20e18); // [0, 20), anchored at 20 ETH

        // event 0 -- deposit-funded: [0, 10) at 1.05 with no exit behind it, so no mark and the slice
        // stays in a gap
        _reportRate(1.05e18);
        assertEq(_reportWithdraw(10e18, 1.05e18), 10.5e18);
        assertEq(redeemManager.getRateMarkCount(), 0);

        // only now does principal stop earning, and a mark starts at the settled height, never below,
        // so it covers precisely the range event 1 will settle
        _reportStoppedEarning(applyRate(10e18, 1.05e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 10e18);
        assertEq(mark.amount, 10e18);
        assertEq(mark.markedEth, 10.5e18);

        // event 1 -- exit-funded, same rate, same shape
        assertEq(_reportWithdraw(10e18, 1.05e18), 10.5e18);
        assertEq(redeemManager.getWithdrawalEventCount(), 2);

        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = 0; // start at event 0 and let the walk carry on into event 1

        // event 0: 10 LsETH matched, 10.5 available, capped at the request rate to 10, so 10 LsETH
        // outstanding and 0.5 exceeding
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(id, 0, 10e18, 10e18, 10e18, 0.5e18);
        // event 1: the same 10.5 available, capped at the mark rate to 10.5, so nothing is left
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(id, 1, 10e18, 10.5e18, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(id, user, 20.5e18, 20e18, 0);
        redeemManager.claimRedeemRequests(ids, eventIds);

        assertEq(user.balance, 20.5e18);
        // 1.00 on the first slice, 1.05 on the second
        assertEq(user.balance, applyRate(10e18, 1e18) + applyRate(10e18, 1.05e18));
        assertEq(redeemManager.getBufferedExceedingEth(), 0.5e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
    }
}
