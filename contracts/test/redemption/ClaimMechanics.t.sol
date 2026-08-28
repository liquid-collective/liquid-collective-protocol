//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionTestBase.sol";

/// @title Redemption claim mechanics
/// @notice Covers the positional side of redemption fulfillment: how requests, withdrawal events and
///         rate marks — three independent interval stacks laid over the SAME ascending cumulative-LsETH
///         axis — line up against each other during a claim.
/// @dev The suites in RedeemManager.1.t.sol pin the one-request/one-mark cases. What is exercised here
///      is the misalignment: a mark that stops between two requests, a mark that ends inside one, a
///      request created after a mark was taken, resolution across a long and partly degenerate
///      withdrawal stack, and a claim walk split by `_depth`.
contract RedemptionClaimMechanicsTests is RedemptionTestBase {
    // ─────────────────────────────────────────────────────────────────────────
    // F1 — one withdrawal event, two requests, one mark covering only the first
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice **Scenario:** two requests A and B of 30 LsETH each, both opened at rate 1.00, are
    ///         settled by ONE withdrawal event of 60 LsETH funded at rate 1.05. A single rate mark
    ///         covers [0, 30) — exactly A — and stops short of B.
    /// @notice **Expected:** A is paid at the marked rate (1.05 -> 31.5 ETH) and B at its own request
    ///         rate (1.00 -> 30 ETH), even though both payouts come out of the same event's 63 ETH.
    ///         The 1.5 ETH the event carried above B's cap is confiscated to BufferedExceedingEth.
    /// @dev This is the clearest demonstration that marks are POSITIONAL and that the ETH funding a
    ///      withdrawal event is FUNGIBLE. The event does not know which of its 63 ETH came from an exit
    ///      and which from the deposit buffer, and it does not need to: the mark, not the event, decides
    ///      the rate, and it does so per position on the axis.
    function testOneEventTwoRequestsMarkCoversFirstOnly() external {
        address userA = _generateAllowlistedUser(1);
        address userB = _generateAllowlistedUser(2);

        // both requests are anchored at rate 1.00, so each has a request-time value of 30 ETH
        river.sudoSetRate(1e18);
        uint32 idA = _openRequest(userA, 30e18); // occupies [0, 30) on the axis
        uint32 idB = _openRequest(userB, 30e18); // occupies [30, 60)
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, 30e18);

        // the principal backing the FIRST 30 LsETH of the queue stopped earning at a pool rate of 1.05
        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));

        // the mark ends at 30e18, i.e. exactly where B begins — B is in the gap above it
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 30e18);
        assertEq(mark.markedEth, applyRate(30e18, 1.05e18)); // 31.5 ETH
        assertEq(_markCursor(), 30e18);

        // ONE withdrawal event settles both requests at once, carrying 63 ETH for 60 LsETH
        uint256 withdrawnEth = _reportWithdraw(60e18, 1.05e18);
        assertEq(withdrawnEth, 63e18);
        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(_settledHeight(), 60e18);

        // A: pro-rata share of the event is 31.5 ETH, cap is the mark's rate over the whole slice ->
        // 30 * 31.5 / 30 = 31.5 ETH. The cap does not bind, so nothing is confiscated for A.
        assertEq(_claim(idA), 31.5e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // B: identical pro-rata share of the very same event, 31.5 ETH, but its slice [30, 60) sits
        // entirely above the mark, so the cap is the request-time rate -> 30 * 1.00 = 30 ETH.
        assertEq(_claim(idB), 30e18);

        // the 1.5 ETH the event carried above B's cap goes back to the remaining holders
        assertEq(redeemManager.getBufferedExceedingEth(), 1.5e18);
        assertEq(address(redeemManager).balance, 1.5e18); // 63 in, 61.5 paid out
    }

    /// @notice **Scenario:** same two requests and same single 60 LsETH withdrawal event, but the mark
    ///         now covers [0, 40) — it crosses the A/B boundary at 30 and dies 10 LsETH into B.
    /// @notice **Expected:** A is fully marked and paid 31.5 ETH; B is paid a BLEND, 10 LsETH at the
    ///         mark rate 1.05 plus 20 LsETH at its request rate 1.00 = 10.5 + 20 = 30.5 ETH.
    /// @dev Exercises case 3 -> case "past the last mark" inside `_sliceCap`: the walk splits B's slice
    ///      at the mark's end position, which no other test does for a mark that started under a
    ///      DIFFERENT request.
    function testOneEventTwoRequestsMarkStraddlesTheBoundary() external {
        address userA = _generateAllowlistedUser(1);
        address userB = _generateAllowlistedUser(2);

        river.sudoSetRate(1e18);
        uint32 idA = _openRequest(userA, 30e18); // [0, 30)
        uint32 idB = _openRequest(userB, 30e18); // [30, 60)

        // 40 LsETH of principal stopped earning at 1.05: enough for all of A and the first third of B
        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(40e18, 1.05e18));

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 40e18);
        assertEq(mark.markedEth, 42e18); // 40 LsETH * 1.05
        // the mark's end lands strictly inside B
        assertEq(_markCursor(), 40e18);

        uint256 withdrawnEth = _reportWithdraw(60e18, 1.05e18);
        assertEq(withdrawnEth, 63e18);

        // A: fully inside the mark. Its cap is a pro-rata slice of the mark, 30 * 42 / 40 = 31.5 ETH,
        // which is exactly its 31.5 ETH pro-rata share of the event.
        assertEq(_claim(idA), 31.5e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // B: the exact split. [30, 40) is marked -> 10 * 42 / 40 = 10.5 ETH.
        //                     [40, 60) is in the gap -> 20 * 1.00 = 20 ETH.
        uint256 markedLeg = 10.5e18;
        uint256 unmarkedLeg = 20e18;
        assertEq(_claim(idB), markedLeg + unmarkedLeg); // 30.5 ETH
        // and it is genuinely a blend: strictly above the pure request rate, strictly below the pure
        // mark rate, so neither branch alone could produce this number
        assertTrue(markedLeg + unmarkedLeg > applyRate(30e18, 1e18));
        assertTrue(markedLeg + unmarkedLeg < applyRate(30e18, 1.05e18));

        // 63 ETH in, 31.5 + 30.5 = 62 ETH out
        assertEq(redeemManager.getBufferedExceedingEth(), 1e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // F5 — claim ordering across requests
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice **Scenario:** three requests A, B, C opened at rates 1.00 / 1.02 / 1.04, a single mark
    ///         covering [0, 15) (all of A and half of B), and one withdrawal event settling all 30
    ///         LsETH at 1.10. The identical scenario is run twice: once claiming A, B, C in queue order
    ///         and once claiming C, B, A youngest-first.
    /// @notice **Expected:** byte-identical payouts in both runs.
    /// @dev Claim order cannot matter because a request's position on the axis is fixed by the requests
    ///      that PRECEDE it and is never touched by a claim on any other request: `_saveRedeemRequest`
    ///      only ever writes the id it was given, and the end position `height + amount` it preserves is
    ///      what the next request's height was derived from at creation time. Marks and withdrawal
    ///      events are likewise addressed by absolute position, never by "the next unclaimed one". So
    ///      the three claims read three disjoint, immutable intervals.
    function testClaimOrderAcrossRequestsDoesNotAffectPayouts() external {
        // fix the scenario in place, then replay it under two different claim orders
        uint256 snapshotId = vm.snapshot();

        (uint256 aInOrder, uint256 bInOrder, uint256 cInOrder, uint256 exceedingInOrder) =
            _runThreeRequestScenario(false);

        assertTrue(vm.revertTo(snapshotId));

        (uint256 aReversed, uint256 bReversed, uint256 cReversed, uint256 exceedingReversed) =
            _runThreeRequestScenario(true);

        // per-request payouts are identical...
        assertEq(aReversed, aInOrder);
        assertEq(bReversed, bInOrder);
        assertEq(cReversed, cInOrder);
        // ...and so is the ETH sent back to the remaining holders
        assertEq(exceedingReversed, exceedingInOrder);

        // pinned absolutely as well, so this cannot pass by both runs being wrong in the same way:
        // A is entirely marked            -> 10 * 15.9 / 15                = 10.6 ETH
        // B straddles the mark's end      -> 5 * 15.9 / 15 + 5 * 1.02      = 5.3 + 5.1 = 10.4 ETH
        // C is entirely above the mark    -> 10 * 1.04                     = 10.4 ETH
        assertEq(aInOrder, 10.6e18);
        assertEq(bInOrder, 10.4e18);
        assertEq(cInOrder, 10.4e18);
        // 33 ETH settled, 31.4 ETH paid
        assertEq(exceedingInOrder, 1.6e18);
    }

    /// @dev Builds the three-request/one-mark/one-event scenario and claims it either in queue order
    ///      (A, B, C) or youngest-first (C, B, A), returning the per-recipient payouts.
    function _runThreeRequestScenario(bool _youngestFirst)
        internal
        returns (uint256 receivedA, uint256 receivedB, uint256 receivedC, uint256 exceeding)
    {
        address userA = _generateAllowlistedUser(1);
        address userB = _generateAllowlistedUser(2);
        address userC = _generateAllowlistedUser(3);

        // three requests opened at three different pool rates, so each has a distinct request rate
        river.sudoSetRate(1e18);
        uint32 idA = _openRequest(userA, 10e18); // [0, 10), anchored at 10.0 ETH
        river.sudoSetRate(1.02e18);
        uint32 idB = _openRequest(userB, 10e18); // [10, 20), anchored at 10.2 ETH
        river.sudoSetRate(1.04e18);
        uint32 idC = _openRequest(userC, 10e18); // [20, 30), anchored at 10.4 ETH

        // 15 LsETH stopped earning at 1.06: covers A completely and the lower half of B
        river.sudoSetRate(1.06e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(15e18, 1.06e18));
        assertEq(redeemManager.getRateMarkDetails(0).amount, 15e18);
        assertEq(redeemManager.getRateMarkDetails(0).markedEth, 15.9e18);

        // the pool appreciates once more and one event settles the whole queue at 1.10, i.e. above every
        // cap rate in play (the mark's 1.06 and the three request rates 1.00 / 1.02 / 1.04)
        river.sudoSetRate(1.1e18);
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

        // a single batched call, so the two runs differ only in the order of the entries
        uint32[] memory eventIds = new uint32[](3);
        redeemManager.claimRedeemRequests(ids, eventIds);

        return (userA.balance, userB.balance, userC.balance, redeemManager.getBufferedExceedingEth());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // F6 — a request created after a mark was taken
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice **Scenario:** request A is opened at 1.00 and marked at 1.05. Only THEN is request B
    ///         opened, at a pool rate of 1.08. Both are settled by one event funded at 1.10.
    /// @notice **Expected:** B's height sits at the mark's end position, so no part of it is covered:
    ///         B is paid at its own request rate (32.4 ETH = 30 * 1.08), while A keeps the whole mark
    ///         (31.5 ETH = 30 * 1.05). Opening B does not mutate the mark in any way.
    /// @dev The three rates are deliberately all different so B's payout identifies which one was used:
    ///      1.05 would mean B stole A's mark, 1.10 would mean the cap was ignored.
    function testRequestOpenedAfterMarkIsUnaffectedByIt() external {
        address userA = _generateAllowlistedUser(1);
        address userB = _generateAllowlistedUser(2);

        river.sudoSetRate(1e18);
        uint32 idA = _openRequest(userA, 30e18); // [0, 30) anchored at 30 ETH

        // A's backing principal stops earning at 1.05, marking [0, 30)
        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));
        RateMarkStack.RateMark memory markBefore = redeemManager.getRateMarkDetails(0);
        assertEq(markBefore.height, 0);
        assertEq(markBefore.amount, 30e18);
        assertEq(markBefore.markedEth, 31.5e18);

        // only now does B join the queue, at a higher pool rate
        river.sudoSetRate(1.08e18);
        uint32 idB = _openRequest(userB, 30e18); // [30, 60) anchored at 32.4 ETH
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, 30e18);
        assertEq(redeemManager.getRedeemRequestDetails(idB).maxRedeemableEth, 32.4e18);

        // the new request appends above the mark cursor; the mark itself is untouched
        RateMarkStack.RateMark memory markAfter = redeemManager.getRateMarkDetails(0);
        assertEq(markAfter.height, markBefore.height);
        assertEq(markAfter.amount, markBefore.amount);
        assertEq(markAfter.markedEth, markBefore.markedEth);
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(_markCursor(), 30e18);
        // B starts exactly where the mark ends, so it is in the gap by construction
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, _markCursor());

        // the pool appreciates once more, and one event settles both at 1.10 -- above every cap rate in
        // play (A's mark at 1.05 and B's request rate of 1.08) -- so each payout is decided by its own cap
        river.sudoSetRate(1.1e18);
        assertEq(_reportWithdraw(60e18, 1.1e18), 66e18);

        // A: pro-rata 33 ETH clamped to the mark -> 31.5 ETH, 1.5 ETH confiscated
        assertEq(_claim(idA), 31.5e18);
        // B: pro-rata 33 ETH clamped to its OWN request rate -> 32.4 ETH, 0.6 ETH confiscated
        assertEq(_claim(idB), 32.4e18);

        // and the mark is still exactly as it was pushed, after both claims
        RateMarkStack.RateMark memory markFinal = redeemManager.getRateMarkDetails(0);
        assertEq(markFinal.height, 0);
        assertEq(markFinal.amount, 30e18);
        assertEq(markFinal.markedEth, 31.5e18);

        assertEq(redeemManager.getBufferedExceedingEth(), 2.1e18); // 1.5 + 0.6
    }

    // ─────────────────────────────────────────────────────────────────────────
    // F8 — resolution across a long, partly degenerate withdrawal stack
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice **Scenario:** 9 requests and 12 withdrawal events. Every event abuts the next by
    ///         construction (the stack is contiguous: `height = previous.height + previous.amount`),
    ///         event 3 is ZERO-WIDTH, some requests need two events and some share one, and the last
    ///         request is never settled.
    /// @notice **Expected:** `resolveRedeemRequests` returns the correct event for the head, middle and
    ///         tail of the queue and skips the zero-width event; -1 for the unsettled request, -2 for a
    ///         nonexistent id, -3 for a claimed one. Every resolved id then claims successfully — with
    ///         one exception, documented as a FINDING below.
    /// @dev FINDING (pre-existing, not introduced by the rate-mark work): a zero-width withdrawal event
    ///      bricks the natural full-depth claim of any request that STRADDLES it. `_claimRedeemRequest`
    ///      walks forward event by event; when the walk steps onto an event with `amount == 0` it
    ///      computes `(matchingAmount * withdrawnEth) / withdrawalEvent.amount` with both operands zero
    ///      and reverts with Panic(0x12). Resolution is unaffected — `_isMatch` requires
    ///      `height < height + amount`, which is false for a zero-width event, so the dichotomic search
    ///      correctly steps over it — which means the claimant CAN work around the revert by claiming
    ///      with `depth = 0` and then re-resolving. Reachability: River guards the call with
    ///      `suppliedRedeemManagerDemandInEth > 0`, but the LsETH leg is
    ///      `sharesFromUnderlyingBalance(availableBalanceToRedeem)`, which rounds DOWN and reaches 0 for
    ///      dust while the ETH leg is still non-zero — see
    ///      contracts/src/libraries/LibOracleReporting.sol L593-L613. The dust that funded such an event
    ///      is also permanently stranded: it is never paid out and never reaches BufferedExceedingEth.
    function testResolveAcrossManyWithdrawalEventsIncludingZeroWidth() external {
        address user = _generateAllowlistedUser(1);

        // everything runs at rate 1.00 so a payout equals its LsETH size and the arithmetic below is
        // about positions only
        river.sudoSetRate(1e18);

        // 9 requests, 90 LsETH of demand. Sizes are deliberately uneven so requests and events do not
        // line up one-to-one.
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

        // 12 withdrawal events settling the first 80 LsETH. Contiguity is enforced by reportWithdraw,
        // so every event abuts the next exactly; the interesting one is #3, which is zero-width.
        _reportWithdraw(5e18, 1e18); //  0: [0, 5)
        _reportWithdraw(5e18, 1e18); //  1: [5, 10)
        _reportWithdraw(10e18, 1e18); // 2: [10, 20)
        // 3: [20, 20) -- zero LsETH but one wei of ETH, mirroring River's rounding path where
        // sharesFromUnderlyingBalance() truncates a dust ETH leg to zero shares
        vm.deal(address(this), 1);
        river.sudoReportWithdraw{value: 1}(address(redeemManager), 0);
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
        // the abutting property, spelled out on the pair around the zero-width event
        assertEq(
            redeemManager.getWithdrawalEventDetails(2).height + redeemManager.getWithdrawalEventDetails(2).amount,
            redeemManager.getWithdrawalEventDetails(3).height
        );
        assertEq(redeemManager.getWithdrawalEventDetails(3).height, redeemManager.getWithdrawalEventDetails(4).height);

        // resolve every request in one batch, plus a nonexistent id
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

        assertEq(resolved[0], 0); // head of the queue -> the very first event
        assertEq(resolved[1], 2); // starts at 10, inside event 2
        // starts at 25, which the zero-width event 3 does NOT match: `_isMatch` needs
        // height < height + amount, false when amount == 0. The search steps over it to event 4.
        assertEq(resolved[2], 4);
        assertEq(resolved[3], 5);
        assertEq(resolved[4], 6); // middle of the queue
        assertEq(resolved[5], 7);
        assertEq(resolved[6], 9);
        assertEq(resolved[7], 10); // tail of the settled range
        assertEq(resolved[8], -1); // RESOLVE_UNSATISFIED: height 80 == settled height, nothing covers it
        assertEq(resolved[9], -2); // RESOLVE_OUT_OF_BOUNDS

        // ── claim each request using its own resolved id ──

        // r0 walks events 0 and 1 (5 + 5)
        assertEq(_claim(r0), 10e18);
        // once fully claimed the same id resolves to RESOLVE_FULLY_CLAIMED
        uint32[] memory one = new uint32[](1);
        one[0] = r0;
        assertEq(redeemManager.resolveRedeemRequests(one)[0], -3);

        // r1 is the straddling request. Its resolved id is correct, but the full-depth walk steps from
        // event 2 onto the zero-width event 3 and divides zero by zero. See the FINDING above.
        {
            uint32[] memory ids = new uint32[](1);
            ids[0] = r1;
            uint32[] memory eventIds = new uint32[](1);
            eventIds[0] = 2;
            vm.expectRevert(stdError.divisionError);
            redeemManager.claimRedeemRequests(ids, eventIds);
        }
        // the workaround: stop the walk before it reaches the zero-width event...
        assertEq(_claimWithDepth(r1, 2, 0), 10e18);
        // ...and re-resolve. The residual now starts at 20, which resolves past the zero-width event.
        one[0] = r1;
        assertEq(redeemManager.resolveRedeemRequests(one)[0], 4);
        assertEq(_claim(r1), 5e18);

        // the remaining requests all claim straight through their resolved ids
        assertEq(_claim(r2), 5e18); // partial slice of event 4
        assertEq(_claim(r3), 10e18);
        assertEq(_claim(r4), 10e18);
        assertEq(_claim(r5), 10e18); // walks events 7 and 8
        assertEq(_claim(r6), 10e18);
        assertEq(_claim(r7), 10e18); // walks events 10 and 11

        // every settled LsETH was paid at 1:1, so nothing was ever capped
        assertEq(user.balance, 80e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        // ...except the wei that funded the zero-width event, which is stranded: not paid out, and not
        // counted as exceeding either
        assertEq(address(redeemManager).balance, 1);

        // r8 is still unsatisfied after all of that
        one[0] = r8;
        assertEq(redeemManager.resolveRedeemRequests(one)[0], -1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // F9 — the residual auto-assigned forward
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice **Scenario:** one 30 LsETH request opened at rate 1.00, settled by three consecutive
    ///         10 LsETH events funded at 1.05, 0.95 and 1.10. It is claimed twice over: once in a
    ///         single full-depth call, then — after reverting — three times with `depth = 0`.
    /// @notice **Expected:** the three partial payouts (10 + 9.5 + 10 = 29.5 ETH) sum to exactly the
    ///         single-call payout, and the end-position invariant `height + amount == 30e18` holds
    ///         after every one of them.
    /// @dev `depth = 0` claims a single event and returns. Nothing tells the next claim where to
    ///      continue: the residual finds the next event on its own, because `_claimRedeemRequest` raises
    ///      `height` by exactly the amount it lowered `amount`, and the withdrawal stack is contiguous —
    ///      so the new height IS the next event's height. That is the whole mechanism, and the invariant
    ///      asserted after each step is what guarantees it.
    function testResidualAutoAssignsForwardAcrossDepthZeroClaims() external {
        address user = _generateAllowlistedUser(1);

        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18); // [0, 30), anchored at 30 ETH -> cap of 1.00 per LsETH

        // three consecutive events at three different settlement rates: one above the cap, one below,
        // one above. Each is swept at the pool rate live at that moment, so the pool walks 1.05 -> 0.95
        // (a slashing) -> 1.10 across the three reports that push them.
        river.sudoSetRate(1.05e18);
        assertEq(_reportWithdraw(10e18, 1.05e18), 10.5e18); // event 0, [0, 10)
        river.sudoSetRate(0.95e18);
        assertEq(_reportWithdraw(10e18, 0.95e18), 9.5e18); //  event 1, [10, 20)
        river.sudoSetRate(1.1e18);
        assertEq(_reportWithdraw(10e18, 1.1e18), 11e18); //    event 2, [20, 30)

        // baseline: what one uninterrupted call pays
        uint256 snapshotId = vm.snapshot();
        uint256 singleCallPayout = _claim(id);
        assertEq(singleCallPayout, 29.5e18); // 10 (capped) + 9.5 (uncapped) + 10 (capped)
        // 31 ETH settled, 29.5 ETH paid: 0.5 confiscated on event 0, none on event 1, 1.0 on event 2
        assertEq(redeemManager.getBufferedExceedingEth(), 1.5e18);
        assertTrue(vm.revertTo(snapshotId));

        // and now the same thing in three bites
        RedeemQueueV2.RedeemRequest memory request = redeemManager.getRedeemRequestDetails(id);
        assertEq(request.height + request.amount, 30e18);

        // bite 1 — event 0 carries 10.5 ETH for the slice but the cap is 10 ETH, so 0.5 is confiscated
        uint256 first = _claimWithDepth(id, 0, 0);
        assertEq(first, 10e18);
        request = redeemManager.getRedeemRequestDetails(id);
        assertEq(request.height, 10e18);
        assertEq(request.amount, 20e18);
        assertEq(request.height + request.amount, 30e18); // INVARIANT
        assertEq(redeemManager.getBufferedExceedingEth(), 0.5e18);

        // bite 2 — event 1 settled BELOW the request rate, so the cap does not bind and the redeemer
        // eats the loss in full
        uint256 second = _claimWithDepth(id, 1, 0);
        assertEq(second, 9.5e18);
        request = redeemManager.getRedeemRequestDetails(id);
        assertEq(request.height, 20e18);
        assertEq(request.amount, 10e18);
        assertEq(request.height + request.amount, 30e18); // INVARIANT
        assertEq(redeemManager.getBufferedExceedingEth(), 0.5e18); // unchanged

        // bite 3 — event 2 carries 11 ETH against the same 10 ETH cap, so a further 1.0 is confiscated
        uint256 third = _claimWithDepth(id, 2, 0);
        assertEq(third, 10e18);
        request = redeemManager.getRedeemRequestDetails(id);
        assertEq(request.height, 30e18);
        assertEq(request.amount, 0);
        assertEq(request.height + request.amount, 30e18); // INVARIANT, even fully claimed
        assertEq(redeemManager.getBufferedExceedingEth(), 1.5e18);

        // splitting the walk changes nothing about what the redeemer or the pool gets
        assertEq(first + second + third, singleCallPayout);
        assertEq(user.balance, 29.5e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // F10 — one claim spanning a deposit-funded event and an exit-funded event
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice **Scenario:** one 20 LsETH request opened at 1.00. Event 0 settles its first half with
    ///         no mark over that range (a fill funded out of the deposit buffer). A mark is then pushed
    ///         at 1.05 over the second half, and event 1 settles it (a fill funded by an exit). The
    ///         request is claimed in ONE call spanning both events.
    /// @notice **Expected:** the request rate is applied to the first slice (10 ETH) and the mark rate
    ///         to the second (10.5 ETH), for 20.5 ETH total; one `SatisfiedRedeemRequest` is emitted per
    ///         event, in order, followed by a single aggregate `ClaimedRedeemRequest`.
    /// @dev This is the mixed-funding case the gap semantics exist for: both events are funded at the
    ///      same 1.05 pool rate and are indistinguishable as ETH, and only the presence or absence of a
    ///      mark over their range separates the two payouts.
    function testClaimSpanningUnmarkedThenMarkedEventsBlendsAndEmitsPerEvent() external {
        address user = _generateAllowlistedUser(1);

        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 20e18); // [0, 20), anchored at 20 ETH

        // event 0 — deposit-funded: it settles [0, 10) at a pool rate of 1.05, but no exit backed it,
        // so no mark is pushed and the slice stays in a gap
        river.sudoSetRate(1.05e18);
        assertEq(_reportWithdraw(10e18, 1.05e18), 10.5e18);
        assertEq(redeemManager.getRateMarkCount(), 0);

        // only now does principal stop earning. The mark starts at the settled height, never below it,
        // so it covers [10, 20) — precisely the range event 1 will settle.
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(10e18, 1.05e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 10e18);
        assertEq(mark.amount, 10e18);
        assertEq(mark.markedEth, 10.5e18);

        // event 1 — exit-funded, same 1.05 rate, same shape as event 0
        assertEq(_reportWithdraw(10e18, 1.05e18), 10.5e18);
        assertEq(redeemManager.getWithdrawalEventCount(), 2);

        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = 0; // start at event 0 and let the walk carry on into event 1

        // slice on event 0: 10 LsETH matched, 10.5 ETH available, capped at the request rate to 10 ETH,
        // 10 LsETH still outstanding, 0.5 ETH exceeding
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(id, 0, 10e18, 10e18, 10e18, 0.5e18);
        // slice on event 1: 10 LsETH matched, 10.5 ETH available, capped at the MARK rate to 10.5 ETH —
        // the cap does not bind, nothing outstanding, nothing exceeding
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(id, 1, 10e18, 10.5e18, 0, 0);
        // one aggregate claim event for the whole call: 20.5 ETH for 20 LsETH, fully claimed
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(id, user, 20.5e18, 20e18, 0);
        redeemManager.claimRedeemRequests(ids, eventIds);

        assertEq(user.balance, 20.5e18);
        // the two slices really were priced differently: 1.00 on the first, 1.05 on the second
        assertEq(user.balance, applyRate(10e18, 1e18) + applyRate(10e18, 1.05e18));
        assertEq(redeemManager.getBufferedExceedingEth(), 0.5e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
    }
}
