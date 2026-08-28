//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionTestBase.sol";

/// @title Rounding, caps and boundary coverage for redemption fulfillment
/// @notice Every payout in this system is `min(pro-rata of the withdrawal event's ETH, _sliceCap(...))`
///         and every rate in it is an integer division that truncates DOWN. This suite pins the exact
///         wei that falls out of both, at the boundaries where the two interact: a cap that is raised
///         above what the protocol actually received, dust-scale requests and marks, zero-width
///         withdrawal events, the clamped-mark rescaling, and the exact-fit demand boundary.
contract RedemptionRoundingAndCapsTests is RedemptionTestBase {
    /// Scenario: a rate mark locks a HIGH rate (1.5) over the whole request, then the pool is slashed
    ///           to 0.6 before the exit is actually swept, so the withdrawal event arrives carrying far
    ///           less ETH than the mark promised.
    /// Expected: the payout is the withdrawal event's pro-rata ETH (18 ETH), not the cap (45 ETH); the
    ///           27 ETH of mark headroom is simply wasted; and because the cap never bound, NOTHING is
    ///           diverted to `BufferedExceedingEth`.
    /// @dev The complement of `testMarkIsNotAFloorOnSlashing`, which slashes by 10% around a 1.05 mark.
    ///      Here the slashing is deep enough that the mark's headroom is more than half the cap, and the
    ///      three consequences (payout, wasted headroom, empty buffer) are each pinned to the wei, along
    ///      with the ETH budget stranded on the request and the manager's residual balance.
    function testSlashingBetweenMarkAndSweepWastesMarkHeadroomWithoutBuffering() external {
        _upgradeToV1_3();
        address user = _generateAllowlistedUser(0);

        // request 30 LsETH at a pool rate of 1.0 -> anchor is (30 LsETH, 30 ETH)
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);
        assertEq(redeemManager.getRedeemRequestAnchor(id).ethAtRequest, 30e18);

        // the backing principal crosses exit_epoch while the pool rate is 1.5, locking 45 ETH over the
        // whole 30 LsETH span. reportedLsETH == markable, so the clamped-mark division is NOT taken and
        // markedEth is exactly the reported figure.
        river.sudoSetRate(1.5e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.5e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 30e18);
        assertEq(mark.markedEth, 45e18);

        // ...and only THEN the pool is slashed, to 0.6. The exit is swept at the depressed rate, so the
        // withdrawal event carries 18 ETH against the 30 LsETH it settles - 27 ETH short of the mark.
        river.sudoSetRate(0.6e18);
        uint256 withdrawnEth = applyRate(30e18, 0.6e18);
        assertEq(withdrawnEth, 18e18);

        uint256 received = _settleAndClaim(id, 30e18, 0.6e18);

        // (1) the payout is the event's pro-rata ETH: (30e18 * 18e18) / 30e18, exact, no truncation
        assertEq(received, 18e18);
        assertEq(received, withdrawnEth);
        // the mark is a ceiling only - it did not lift the payout back towards 45 ETH
        assertTrue(received < mark.markedEth);

        // (2) the mark's headroom is wasted, not carried anywhere: 45 ETH of entitlement, 18 ETH paid
        assertEq(mark.markedEth - received, 27e18);
        // the mark itself is untouched by the claim; nothing reclaims the unused span
        assertEq(redeemManager.getRateMarkDetails(0).markedEth, 45e18);

        // (3) nothing lands in the exceeding buffer: that buffer is only fed when the CAP binds, i.e.
        // when the event supplied more than the request was entitled to. Here the event was the binding
        // side, so there is no surplus to confiscate.
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // every wei the event carried left the contract with the redeemer
        assertEq(address(redeemManager).balance, 0);

        // the request is fully claimed; the stale request-time ETH budget keeps its unspent remainder
        // (30 requested - 18 paid), which no longer bounds anything post-upgrade
        RedeemQueueV2.RedeemRequest memory request = redeemManager.getRedeemRequestDetails(id);
        assertEq(request.amount, 0);
        assertEq(request.maxRedeemableEth, 12e18);
    }

    /// Scenario: a mark raises every request's cap to 2x its request-time value (well above anything the
    ///           protocol has actually received), then ONE withdrawal event settles three requests
    ///           (10 / 20 / 30 LsETH) while carrying only `61e18 - 1` wei.
    /// Expected: the clamp against the event still binds for all three, so the protocol never pays out
    ///           ETH it has not received. The sum of the three payouts is exactly the event's
    ///           `withdrawnEth` minus 1 wei of truncation dust.
    /// @dev The dust is deliberate and quantified below: each payout is
    ///      `(amount_i * withdrawnEth) / 60e18`, three independent floors. With `withdrawnEth == 61e18 - 1`
    ///      the exact shares are W/6, W/3 and W/2, so the fractional parts are 1/2, 0 and 1/2 - B's third
    ///      divides exactly, A's and C's halves do not. The two halves sum to exactly 1 wei, and that is
    ///      the whole of the loss. The lost wei is NOT routed to `BufferedExceedingEth` - it simply stays
    ///      in the RedeemManager's ETH balance, where it is neither claimable by a redeemer nor pullable by
    ///      River via `pullExceedingEth`.
    /// @dev UNREACHABLE WITHDRAWAL EVENT. The mark below is one River would compute
    ///      (`sharesFromUnderlyingBalance(120e18) == 60e18` at a pool rate of 2.0), but the
    ///      `{withdrawnEth: 61e18 - 1, amount: 60e18}` event is not, at ANY pool rate.
    ///      `_reportWithdrawToRedeemManager` derives the pair from a single rate on one of two branches:
    ///      `withdrawnEth = underlyingBalanceFromShares(60e18) == 60 * rate`, always a multiple of 60 and
    ///      so never `61e18 - 1`; or, when the demand outruns `BalanceToRedeem`,
    ///      `amount = sharesFromUnderlyingBalance(withdrawnEth)`, whose rate interval for `amount == 60e18`
    ///      contains no integer. The event is hand-built because it is the shortest way to put three
    ///      independent floors of the same quotient into one claim.
    ///      Consequence worth knowing: with a REACHABLE full-demand event `withdrawnEth == 60 * rate`, so
    ///      each payout `size * withdrawnEth / 60e18 == (size / 1e18) * rate` divides exactly and this
    ///      stranded-dust phenomenon cannot arise from whole-ether request sizes at all - it needs sizes
    ///      that are not whole multiples of 1e18. Reproducing it realistically is deferred.
    function testCapAboveWithdrawalEventStillClampsToEventEth() external {
        _upgradeToV1_3();
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);
        address userC = _generateAllowlistedUser(2);

        // three requests at a pool rate of 1.0: heights 0 / 10 / 30, total demand 60 LsETH
        river.sudoSetRate(1e18);
        uint32 idA = _openRequest(userA, 10e18);
        uint32 idB = _openRequest(userB, 20e18);
        uint32 idC = _openRequest(userC, 30e18);
        assertEq(redeemManager.getRedeemDemand(), 60e18);

        // the pool doubles, then the whole 60 LsETH of demand is marked at that rate of 2.0, doubling
        // every cap. At 2.0 `sharesFromUnderlyingBalance(120e18) == 60e18`, so this is the pair River
        // itself would derive. Nothing has yet SUPPLIED that ETH though: the mark is pure entitlement
        // until a withdrawal event arrives, which is what the rest of the test leans on.
        river.sudoSetRate(2e18);
        river.sudoReportStoppedEarning(address(redeemManager), 120e18);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.amount, 60e18);
        assertEq(mark.markedEth, 120e18);
        // per-request caps: 20 / 40 / 60 ETH, each 2x the request-time value
        assertEq((10e18 * mark.markedEth) / mark.amount, 20e18);
        assertEq((20e18 * mark.markedEth) / mark.amount, 40e18);
        assertEq((30e18 * mark.markedEth) / mark.amount, 60e18);

        // one withdrawal event settles all 60 LsETH but carries only 61 ETH minus 1 wei - far below the
        // 120 ETH of aggregate cap, and chosen so two of the three pro-rata divisions truncate
        uint256 withdrawnEth = 61e18 - 1;
        vm.deal(address(this), withdrawnEth);
        river.sudoReportWithdraw{value: withdrawnEth}(address(redeemManager), 60e18);
        assertEq(address(redeemManager).balance, withdrawnEth);

        uint256 receivedA = _claim(idA);
        uint256 receivedB = _claim(idB);
        uint256 receivedC = _claim(idC);

        // each payout is the event's pro-rata ETH, truncated DOWN; every cap (20 / 40 / 60) is slack
        assertEq(receivedA, (10e18 * withdrawnEth) / 60e18);
        assertEq(receivedB, (20e18 * withdrawnEth) / 60e18);
        assertEq(receivedC, (30e18 * withdrawnEth) / 60e18);
        assertEq(receivedA, 10166666666666666666);
        assertEq(receivedB, 20333333333333333333);
        assertEq(receivedC, 30499999999999999999);
        assertTrue(receivedA < 20e18 && receivedB < 40e18 && receivedC < 60e18);

        // solvency: the protocol paid out strictly less than the event supplied, despite caps worth 2x
        uint256 totalPaid = receivedA + receivedB + receivedC;
        assertEq(totalPaid, withdrawnEth - 1);
        assertTrue(totalPaid < withdrawnEth);

        // the cap never bound, so nothing was confiscated to the exceeding buffer
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        // the single wei of truncation dust is stranded in the manager's balance: outside the exceeding
        // buffer, so `pullExceedingEth` cannot retrieve it either
        assertEq(address(redeemManager).balance, 1);
        river.pullExceedingEth(address(redeemManager), type(uint256).max);
        assertEq(address(redeemManager).balance, 1);
    }

    /// Scenario: dust-scale arithmetic. Two 1 wei redeem requests, a 1 wei rate mark covering only the
    ///           first, and a single 2 wei-wide withdrawal event carrying 3 wei of ETH.
    /// Expected: no division by zero anywhere (every denominator - `event.amount`, `mark.amount`,
    ///           `anchor.lsETHAtRequest` - is 1 or 2), and each truncating division floors as documented.
    ///           Each redeemer is paid exactly 1 wei; the 3rd wei is truncation dust.
    /// @dev Pins the smallest non-degenerate state the fulfillment path can be in. The 1 wei mark
    ///      exercises `(markedAmount * mark.markedEth) / markAmount` with markAmount == 1, and the
    ///      second request exercises `_sliceCap`'s case-2 branch (a mark that ENDS at the slice start,
    ///      one wei wide) followed by the past-the-last-mark branch.
    /// @dev Every leg is derived from the rate in force when it is reported rather than hand-assembled,
    ///      so the whole sequence is one River could produce:
    ///        mark:  at 2.0, `sharesFromUnderlyingBalance(2) == 2 * 1e18 / 2e18 == 1`
    ///        event: at 1.5, `underlyingBalanceFromShares(2) == 2 * 1.5e18 / 1e18 == 3`
    ///      The `sudoSetRate` calls stand for the intervening oracle reports; request rate 1.0, mark rate
    ///      2.0 (the pre-report rate of a later report) and settlement rate 1.5 (the post-report rate) is
    ///      an appreciate-then-slash sequence, which is exactly when a mark becomes a binding ceiling.
    function testDustScaleRequestAndMarkTruncateAsDocumented() external {
        _upgradeToV1_3();
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);

        // two 1 wei requests at a rate of 1.0 -> each anchor is (1 wei LsETH, 1 wei ETH)
        river.sudoSetRate(1e18);
        uint32 idA = _openRequest(userA, 1);
        uint32 idB = _openRequest(userB, 1);
        assertEq(redeemManager.getRedeemRequestAnchor(idA).lsETHAtRequest, 1);
        assertEq(redeemManager.getRedeemRequestAnchor(idA).ethAtRequest, 1);
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, 1);
        assertEq(redeemManager.getRedeemDemand(), 2);

        // the pool doubles, then 1 wei of principal - worth 2 wei at that rate - stops earning: a mark
        // covering [0, 1) at a locked rate of 2.0. reportedLsETH (1) <= markable (2), so no clamp and no
        // clamped-mark division.
        river.sudoSetRate(2e18);
        river.sudoReportStoppedEarning(address(redeemManager), 2);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 1);
        assertEq(mark.markedEth, 2);
        assertEq(_markCursor(), 1);

        // the pool is then slashed back to 1.5 and one withdrawal event settles both wei of demand,
        // carrying `underlyingBalanceFromShares(2) == 3` wei: 1.5 wei per wei of LsETH
        river.sudoSetRate(1.5e18);
        assertEq(_reportWithdraw(2, 1.5e18), 3);
        assertEq(redeemManager.getRedeemDemand(), 0);

        // request A: pro-rata is (1 * 3) / 2 == 1, truncated DOWN from 1.5 in the protocol's favour.
        // Its cap is the mark's locked rate, (1 * 2) / 1 == 2 wei, so the event is the binding side.
        uint256 receivedA = _claim(idA);
        assertEq(receivedA, 1);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // request B: same pro-rata floor, (1 * 3) / 2 == 1. Its slice starts at height 1, exactly where
        // the mark ENDS, so `_sliceCap` discards the mark (case 2) and falls through to the request-time
        // rate: (1 * 1) / 1 == 1 wei. Cap and event tie at 1 wei, so still nothing is confiscated.
        uint256 receivedB = _claim(idB);
        assertEq(receivedB, 1);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // both requests are fully claimed at 1 wei each
        assertEq(redeemManager.getRedeemRequestDetails(idA).amount, 0);
        assertEq(redeemManager.getRedeemRequestDetails(idB).amount, 0);

        // the 3rd wei is the aggregate of the two 0.5 wei truncations: it is left in the manager's
        // balance rather than in the exceeding buffer, so no one can withdraw it
        assertEq(receivedA + receivedB, 2);
        assertEq(address(redeemManager).balance, 1);
    }

    /// Scenario: a ZERO-WIDTH withdrawal event, i.e. `{amount: 0, withdrawnEth: 1}`. Reachable on the
    ///           real report path when `BalanceToRedeem` is 1 wei and the pool rate is above 1, because
    ///           `LibOracleReporting._reportWithdrawToRedeemManager` recomputes the LsETH leg with
    ///           `sharesFromUnderlyingBalance(1)`, which truncates to 0 while the ETH leg stays at 1 wei.
    /// Expected (per design): `_isMatch` can never match a zero-width event - its predicate needs
    ///           `height < height + 0` - so no top-level claim can reach the division by `event.amount`,
    ///           and `resolveRedeemRequests` stays correct for the surrounding requests.
    /// @dev FINDING: the design expectation holds only for the TOP-LEVEL match check. `_claimRedeemRequest`
    ///      recurses into `withdrawalEventId + 1` WITHOUT re-checking `_isMatch`, so a request that spans
    ///      the zero-width event divides by `event.amount == 0` and the whole `claimRedeemRequests` call
    ///      reverts with Panic(0x12). The canonical UX path hits this: `resolveRedeemRequests` returns the
    ///      first matching event, and claiming from it with the default depth reverts. The request is not
    ///      permanently stuck - it can be drained by claiming with `_depth == 0` and then re-resolving
    ///      past the zero-width event - but that requires a caller who knows to do it. Both the revert and
    ///      the two-step recovery are asserted below.
    function testZeroWidthWithdrawalEventBricksSpanningClaim() external {
        _upgradeToV1_3();
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);

        // A spans [0, 20), B spans [20, 30). Total demand 30 LsETH.
        river.sudoSetRate(1e18);
        uint32 idA = _openRequest(userA, 20e18);
        uint32 idB = _openRequest(userB, 10e18);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // event 0 settles the first 10 LsETH of A
        _reportWithdraw(10e18, 1e18);

        // event 1 is the zero-width event: 1 wei of ETH against 0 LsETH of demand. `reportWithdraw`
        // accepts it (0 is never > demand) and debits nothing from the demand.
        vm.deal(address(this), 1);
        river.sudoReportWithdraw{value: 1}(address(redeemManager), 0);

        // event 2 settles the remaining 20 LsETH
        _reportWithdraw(20e18, 1e18);

        // the zero-width event exists, sits at the settled height, and carries the orphaned wei
        assertEq(redeemManager.getWithdrawalEventCount(), 3);
        WithdrawalStack.WithdrawalEvent memory zeroWidth = redeemManager.getWithdrawalEventDetails(1);
        assertEq(zeroWidth.height, 10e18);
        assertEq(zeroWidth.amount, 0);
        assertEq(zeroWidth.withdrawnEth, 1);
        // it consumed no demand: 30 - 10 - 0 - 20 == 0
        assertEq(redeemManager.getRedeemDemand(), 0);
        assertEq(_settledHeight(), 30e18);

        // resolution is unaffected. A (height 0) resolves to event 0; B (height 20e18) resolves to
        // event 2 and NOT to the zero-width event 1, even though event 1 also starts at a height <= 20e18:
        // the zero-width interval is empty, so `_isMatch` rejects it at every position.
        uint32[] memory both = new uint32[](2);
        both[0] = idA;
        both[1] = idB;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(both);
        assertEq(resolved[0], 0);
        assertEq(resolved[1], 2);

        // FINDING: claiming A from its resolved event with the default depth fills 10 LsETH at event 0,
        // then recurses into event 1 unconditionally. There `matchingAmount` is 0 and the payout is
        // `(0 * 1) / 0` -> Panic(0x12), reverting the entire call.
        {
            uint32[] memory ids = new uint32[](1);
            ids[0] = idA;
            uint32[] memory eventIds = new uint32[](1);
            eventIds[0] = 0;
            vm.expectRevert(stdError.divisionError);
            redeemManager.claimRedeemRequests(ids, eventIds);
        }

        // recovery, step 1: claim with `_depth == 0` so the recursion never loads event 1. A is filled
        // for its first 10 LsETH at the event's rate of 1.0 and left partially claimed at height 10e18.
        uint256 firstFill = _claimWithDepth(idA, 0, 0);
        assertEq(firstFill, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(idA).amount, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(idA).height, 10e18);

        // recovery, step 2: A now re-resolves PAST the zero-width event, to event 2, because
        // `_performDichotomicResolution` tests the last event first and event 2 covers [10e18, 30e18).
        uint32[] memory a = new uint32[](1);
        a[0] = idA;
        assertEq(redeemManager.resolveRedeemRequests(a)[0], 2);
        uint256 secondFill = _claim(idA);
        assertEq(secondFill, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(idA).amount, 0);

        // B claims normally against event 2: (10e18 * 20e18) / 20e18
        assertEq(_claim(idB), 10e18);

        // the 1 wei debited from `BalanceToRedeem` and pushed into the zero-width event can never be
        // paid to anyone: no request can match a zero-width event, so it is never part of any
        // `withdrawnEth` pro-rata. It is not routed to the exceeding buffer either, so `pullExceedingEth`
        // cannot return it to River. It is permanently stranded in the manager's ETH balance.
        assertEq(firstFill + secondFill + 10e18, 30e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 1);
        river.pullExceedingEth(address(redeemManager), type(uint256).max);
        assertEq(address(redeemManager).balance, 1);
    }

    /// Scenario: a stopped-earning report whose LsETH leg (7 wei) overshoots the markable demand
    ///           (3 wei), at an eth/LsETH pair (10 / 7) chosen so the clamped-mark rescaling
    ///           `(stoppedEarningEth * lsETHToMark) / reportedLsETH` == `(10 * 3) / 7` truncates.
    /// Expected: the locked rate `markedEth / amount` is strictly BELOW the reported rate
    ///           `stoppedEarningEth / reportedLsETH` - truncation must always favour the protocol, never
    ///           the redeemer. Asserted as the strict cross-multiplied inequality.
    /// @dev `testClampedMarkPreservesReportedRate` only exercises the exactly-divisible case, where the
    ///      locked rate is preserved to the wei. This is the other side: when the rescaling cannot be
    ///      exact, the residual must be dropped downwards. The clamped payout below shows the truncation
    ///      flowing all the way through to the redeemer's ETH.
    /// @dev Both legs are ones River derives from the rate in force, not hand-assembled pairs:
    ///        mark:  at 1.4, `sharesFromUnderlyingBalance(10) == 10 * 1e18 / 1.4e18 == 7` (floored from 7.14)
    ///        event: at 1.6, the demand outruns `BalanceToRedeem`, so the balance-limited branch applies
    ///               and `amount = sharesFromUnderlyingBalance(5) == 5 * 1e18 / 1.6e18 == 3` (from 3.125)
    ///      Note that the reported rate 10/7 is itself a rounding artifact of the 1.4 pool rate, which is
    ///      the point: at dust scale the reported pair never expresses the pool rate exactly, and the
    ///      rescaling has to truncate in the protocol's favour on top of that.
    function testClampedMarkTruncatesLockedRateDownwards() external {
        _upgradeToV1_3();
        address user = _generateAllowlistedUser(0);

        // 3 wei of markable demand at a request rate of 1.0
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 3);

        // the pool appreciates to 1.4, then 10 wei of principal stops earning. River values it at
        // `sharesFromUnderlyingBalance(10) == 7` wei of LsETH, a reported rate of 10/7 ~= 1.42857, but
        // only 3 wei is markable, so the eth leg is rescaled: (10 * 3) / 7 == 30 / 7 == 4.2857 -> 4 wei
        uint256 reportedEth = 10;
        uint256 reportedLsETH = 7;
        river.sudoSetRate(1.4e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(reportedLsETH, 3);
        river.sudoReportStoppedEarning(address(redeemManager), reportedEth);

        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 3);
        // truncated DOWN from 4.2857 to 4
        assertEq(mark.markedEth, 4);
        assertEq(mark.markedEth, (reportedEth * 3) / reportedLsETH);

        // the locked rate is STRICTLY below the reported rate: 4/3 == 1.3333 < 10/7 == 1.42857.
        // Cross-multiplied to avoid a second truncation in the assertion itself: 4 * 7 == 28 < 10 * 3 == 30.
        assertTrue(mark.markedEth * reportedLsETH < reportedEth * mark.amount);
        assertEq(reportedEth * mark.amount - mark.markedEth * reportedLsETH, 2);
        // and it is never above - the direction is what matters, the magnitude is sub-wei (2/7 of a wei)
        assertTrue(mark.markedEth * reportedLsETH <= reportedEth * mark.amount);

        // the truncation flows through to the payout. The pool rises again to 1.6 and 5 wei of
        // `BalanceToRedeem` settles the 3 wei of demand - the balance-limited branch, where the LsETH leg
        // is `sharesFromUnderlyingBalance(5) == 3`. That offers more than the locked rate, so the cap
        // binds at (3 * 4) / 3 == 4 wei
        river.sudoSetRate(1.6e18);
        vm.deal(address(this), 5);
        river.sudoReportWithdraw{value: 5}(address(redeemManager), 3);
        uint256 received = _claim(id);

        assertEq(received, 4);
        // had the rescaling rounded UP to 5 wei, the redeemer would have taken the whole event instead
        assertTrue(received < 5);
        // the wei the truncation withheld goes to the remaining holders via the exceeding buffer
        assertEq(redeemManager.getBufferedExceedingEth(), 1);
    }

    /// Scenario: the ENTIRE LsETH supply is queued for redemption in a single request, and River then
    ///           makes a stopped-earning report whose LsETH leg its own conversion truncates to zero,
    ///           followed by a genuine full-supply report.
    /// Expected: `reportStoppedEarning`'s dual-nonzero guard absorbs the degenerate pair without
    ///           reverting and without pushing an empty mark, the genuine report then marks the whole
    ///           axis through the un-clamped branch (no division at all), and the claim settles.
    /// @dev Case (a) is the ONLY reachable way into the zero-leg guard while the pool has shares. The two
    ///      legs are not independent - `stoppedEarningLsETH = sharesFromUnderlyingBalance(stoppedEarningEth)`
    ///      (LibOracleReporting L217-219) - so a zero LsETH leg against a live 100e18 supply can only come
    ///      from a dust eth leg, and a zero ETH leg forces a zero LsETH leg AND means River never makes the
    ///      call at all (it is gated on `stoppedEarningAmountIncrease > 0`, L392). Earlier revisions of this
    ///      test also passed `(5e18, 0)` and `(0, 5e18)` explicitly; both were removed as unreachable, and
    ///      the first directly contradicted the `totalSupply() == 100e18` assertion above it. The guard
    ///      itself is still exercised defensively against a hand-built pair in
    ///      `RateMarkPlacementTests.testReportStoppedEarningWithZeroEthLegIsDiscarded`.
    /// @dev What this pins is the absence of a mark, not the safety of the trailing
    ///      `(stoppedEarningEth * lsETHToMark) / reportedLsETH`. That division is guarded by the
    ///      `lsETHToMark == 0` return, not by the zero-leg check here: a zero `reportedLsETH` forces
    ///      `lsETHToMark == 0`, so `lsETHToMark > markable` is never true and the clamp is skipped
    ///      entirely. Case (a) therefore never reaches the division, and would not reach it even if the
    ///      `|| _stoppedEarningLsETH == 0` term were deleted. The denominator bound is pinned at its
    ///      boundary in `RateMarkPlacementTests.testClampedMarkDivisionOnlyRunsWithADenominatorOfTwoOrMore`.
    function testEntireSupplyQueuedThenDegenerateStoppedEarningReports() external {
        _upgradeToV1_3();
        address user = _generateAllowlistedUser(0);

        // the whole supply - every LsETH in existence - is queued in one request
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 100e18);
        assertEq(river.totalSupply(), 100e18);
        assertEq(river.balanceOf(address(redeemManager)), 100e18);
        assertEq(redeemManager.getRedeemDemand(), 100e18);

        // (a) a 1 wei delta at a rate of 2.0: River's own conversion truncates the LsETH leg to
        // (1 * 1e18) / 2e18 == 0, which is the only way a live pool reaches the zero-leg guard
        river.sudoSetRate(2e18);
        river.sudoReportStoppedEarning(address(redeemManager), 1);
        assertEq(redeemManager.getRateMarkCount(), 0);

        // a genuine report: the entire 100 LsETH of supply stopped earning, valued at 2.0 == 200 ETH.
        // reportedLsETH (100e18) == markable (100e18), so the clamp does not fire and `markedEth` is the
        // reported figure verbatim - no division, hence no truncation.
        river.sudoReportStoppedEarning(address(redeemManager), 200e18);
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 100e18);
        assertEq(mark.markedEth, 200e18);
        assertEq(_markCursor(), 100e18);

        // the whole supply settles in one event at the marked rate: cap (200 ETH) and event (200 ETH)
        // tie exactly, so the redeemer takes all of it and nothing is confiscated
        uint256 received = _settleAndClaim(id, 100e18, 2e18);
        assertEq(received, 200e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
        assertEq(redeemManager.getRedeemDemand(), 0);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 0);
    }

    /// Scenario: the exact-fit boundary and its two neighbours. (1) a withdrawal event whose LsETH leg
    ///           equals the outstanding demand to the wei; (2) demand one wei ABOVE what the event
    ///           settles; (3) an event carrying one wei MORE ETH than the demand it settles is worth.
    /// Expected: (1) a full fill with `_isMatch` satisfied at the lower endpoint and rejected at the
    ///           upper one (the interval is half-open), leaving no dust in the queue, the demand or the
    ///           exceeding buffer; (2) a partial fill leaving exactly 1 wei of demand, unsatisfied until
    ///           a further event arrives; (3) the surplus wei is confiscated to the exceeding buffer
    ///           rather than paid to the redeemer, because the cap binds one wei below the event.
    function testExactFitDemandBoundaryAndItsOffByOneNeighbours() external {
        _upgradeToV1_3();
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);
        river.sudoSetRate(1e18);

        // ── (1) exact fit: demand == the event's LsETH leg ────────────────────────────────────────
        uint32 idA = _openRequest(userA, 30e18);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        _reportWithdraw(30e18, 1e18);
        // the demand is drained to zero by a leg of exactly its own size
        assertEq(redeemManager.getRedeemDemand(), 0);

        // `_isMatch` holds at the LOWER endpoint: the request's height equals the event's height
        assertEq(redeemManager.getRedeemRequestDetails(idA).height, redeemManager.getWithdrawalEventDetails(0).height);
        uint32[] memory a = new uint32[](1);
        a[0] = idA;
        assertEq(redeemManager.resolveRedeemRequests(a)[0], 0);

        uint256 receivedA = _claim(idA);
        assertEq(receivedA, 30e18);

        // ...and is rejected at the UPPER endpoint: the interval is half-open, so a request opened at
        // height 30e18 - exactly where the event ends - does not match it and is unsatisfied
        uint32 idB = _openRequest(userB, 20e18 + 1);
        assertEq(redeemManager.getRedeemRequestDetails(idB).height, 30e18);
        uint32[] memory b = new uint32[](1);
        b[0] = idB;
        assertEq(redeemManager.resolveRedeemRequests(b)[0], -1);

        // no dust anywhere after the exact fit: the request is drained, its ETH budget is drained, the
        // demand carries only the newly opened request, the buffer is empty and so is the balance
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

        // the fill is capped by the event's width, not by the request's: matching == 20e18, and the cap
        // (20e18 * (20e18+1)) / (20e18+1) == 20e18 divides exactly, so the two tie and nothing is buffered
        assertEq(receivedB, 20e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // exactly one wei of the request - and of the demand - survives, and it is unsatisfied
        RedeemQueueV2.RedeemRequest memory requestB = redeemManager.getRedeemRequestDetails(idB);
        assertEq(requestB.amount, 1);
        assertEq(requestB.height, 50e18);
        assertEq(requestB.maxRedeemableEth, 1);
        assertEq(redeemManager.getRedeemDemand(), 1);
        assertEq(redeemManager.resolveRedeemRequests(b)[0], -1);
        assertEq(address(redeemManager).balance, 0);

        // ── (3) demand one wei BELOW the ETH available: 1 wei of demand, 2 wei of ETH ─────────────
        // The pool has doubled by the time the last wei is swept, so the event is funded at a rate of
        // 2.0 - `underlyingBalanceFromShares(1) == 2` - and offers 2 wei where the request-time cap
        // allows (1 * (20e18+1)) / (20e18+1) == 1 wei.
        river.sudoSetRate(2e18);
        _reportWithdraw(1, 2e18);
        assertEq(redeemManager.getWithdrawalEventDetails(2).withdrawnEth, 2);

        uint256 lastWei = _claim(idB);
        // the cap binds one wei below the event: the redeemer gets the request-time wei...
        assertEq(lastWei, 1);
        // ...and the surplus wei is confiscated to the exceeding buffer for the remaining holders
        assertEq(redeemManager.getBufferedExceedingEth(), 1);
        assertEq(address(redeemManager).balance, 1);

        // the queue is now completely drained: no dust left in any request or in the demand
        assertEq(redeemManager.getRedeemRequestDetails(idB).amount, 0);
        assertEq(redeemManager.getRedeemDemand(), 0);
        assertEq(receivedA + receivedB + lastWei, 50e18 + 1);
    }

    /// Scenario: `reportWithdraw` is called with an LsETH leg exactly one wei ABOVE the outstanding
    ///           redeem demand, then with a leg exactly equal to it.
    /// Expected: the first reverts `WithdrawalExceedsRedeemDemand(demand + 1, demand)` - both arguments
    ///           carrying the real values - and leaves the withdrawal stack and the demand untouched.
    ///           The exact-equality call then succeeds and drains the demand to zero.
    /// @dev This bound is the RedeemManager's own solvency guard on the LsETH axis: a leg wider than the
    ///      demand would push a withdrawal event covering positions no request will ever occupy, and the
    ///      unchecked `redeemDemand - _lsETHWithdrawable` immediately below the check would underflow.
    function testReportWithdrawRevertsOneWeiAboveDemandAndAcceptsExactEquality() external {
        _upgradeToV1_3();
        address user = _generateAllowlistedUser(0);

        river.sudoSetRate(1e18);
        _openRequest(user, 30e18);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // one wei above the outstanding demand: rejected, with both arguments reported exactly
        vm.deal(address(this), 30e18 + 1);
        vm.expectRevert(
            abi.encodeWithSignature("WithdrawalExceedsRedeemDemand(uint256,uint256)", 30e18 + 1, uint256(30e18))
        );
        river.sudoReportWithdraw{value: 30e18 + 1}(address(redeemManager), 30e18 + 1);

        // nothing was recorded and nothing was consumed by the rejected call
        assertEq(redeemManager.getWithdrawalEventCount(), 0);
        assertEq(redeemManager.getRedeemDemand(), 30e18);

        // the exact-equality case is accepted: the boundary is inclusive on the demand side
        vm.deal(address(this), 30e18);
        river.sudoReportWithdraw{value: 30e18}(address(redeemManager), 30e18);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory withdrawalEvent = redeemManager.getWithdrawalEventDetails(0);
        assertEq(withdrawalEvent.height, 0);
        assertEq(withdrawalEvent.amount, 30e18);
        assertEq(withdrawalEvent.withdrawnEth, 30e18);
        assertEq(redeemManager.getRedeemDemand(), 0);

        // with the demand now at zero, even a single wei of LsETH is one wei too many
        vm.deal(address(this), 1);
        vm.expectRevert(
            abi.encodeWithSignature("WithdrawalExceedsRedeemDemand(uint256,uint256)", uint256(1), uint256(0))
        );
        river.sudoReportWithdraw{value: 1}(address(redeemManager), 1);
        assertEq(redeemManager.getWithdrawalEventCount(), 1);
    }
}
