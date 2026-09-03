//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionReportBase.sol";

/// @title Stopped-earning launch cutover tests
/// @notice Covers `initializeRedeemManagerV1_3` and the boundary it draws between pre-upgrade demand
///         and the first post-upgrade cohort.
/// @dev The cutover is enforced by two independent mechanisms that are easy to conflate:
///
///      1. A zero `RedeemRequestAnchor` makes a request IGNORE rate marks — it is capped by the
///         legacy pro-rata formula on the decrementing `maxRedeemableEth`.
///      2. The `RateMarkFloor` stops pre-upgrade demand from CONSUMING marks — marks advance a single
///         cursor across the queue, so without it the first reports after the upgrade would spend
///         their credit covering requests that cannot use it.
///
///      The suite below pins the seams between them: the floor derivation itself (B4, B11, B12), the
///      interaction of the floor with the settled height (B5), and the two ways a request can end up
///      excluded from marking — no anchor at all (B7, B8) or an anchor that the floor sits above
///      (B12).
contract RedemptionCutoverTests is RedemptionReportBase {
    /// @dev Storage slot of `word` of queue element `index`. `RedeemQueueV2` is a dynamic array
    ///      living at a raw keccak slot with a stride of 5 words: amount, maxRedeemableEth,
    ///      recipient, height, initiator.
    function _queueSlot(uint256 index, uint256 word) internal pure returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encode(REDEEM_QUEUE_ID_SLOT))) + (index * 5) + word);
    }

    /// Scenario: the whole pre-upgrade queue has already been claimed to the last wei, so every
    /// request carries `amount == 0` and a `height` that has been advanced to its own end position.
    /// Expected: the floor still lands on the true end of the queue. `height + amount` is invariant
    /// across a request's lifetime — the claim path raises `height` by exactly the amount it lowers
    /// `amount` by — so the last element's end position is still the total LsETH ever requested, and
    /// the first post-upgrade mark starts there.
    function testInitializeV1_3OnFullyClaimedQueuePinsFloorAtTotalRequested() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        // two pre-upgrade requests: 30 + 20 == 50 LsETH ever requested
        uint32 first = _openRequest(user, 30e18);
        uint32 second = _openRequest(user, 20e18);
        _stripAnchor(first);
        _stripAnchor(second);

        // settle and claim all of it, so both queue elements are drained
        _reportWithdraw(50e18, 1e18);
        assertEq(_claim(first), 30e18);
        assertEq(_claim(second), 20e18);

        // the drained shape the upgrade will read: amounts at 0, heights advanced to the end positions
        assertEq(redeemManager.getRedeemRequestDetails(first).amount, 0);
        assertEq(redeemManager.getRedeemRequestDetails(first).height, 30e18);
        assertEq(redeemManager.getRedeemRequestDetails(second).amount, 0);
        assertEq(redeemManager.getRedeemRequestDetails(second).height, 50e18);

        // 50e18 == 30e18 + 20e18: the drained tail still reports the total LsETH ever requested
        _pokeVersionTo(2);
        vm.expectEmit(true, true, true, true);
        emit SetRateMarkFloor(50e18);
        redeemManager.initializeRedeemManagerV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 50e18);

        // a post-upgrade request appends at exactly the floor
        uint32 fresh = _openRequest(user, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(fresh).height, 50e18);

        // 10 LsETH of principal stops earning at 1.1 -> a mark of 11 ETH over [50, 60)
        _reportRate(1.1e18);
        _reportStoppedEarning(applyRate(10e18, 1.1e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 50e18);
        assertEq(mark.amount, 10e18);
        assertEq(mark.markedEth, 11e18);

        // and the mark pays out: 11 ETH rather than the 10 ETH the request was quoted at
        assertEq(_settleAndClaim(fresh, 10e18, 1.1e18), 11e18);
    }

    /// Scenario: `reportStoppedEarning` runs while the settled height sits ABOVE the floor. The two
    /// cannot be ordered that way at upgrade time — `RedeemDemand` guarantees cumulative withdrawals
    /// never exceed cumulative requests, so `settledHeight <= floor` always holds the instant the
    /// floor is pinned — but once post-upgrade demand extends the queue, withdrawal events settle
    /// straight past the old queue end.
    /// Expected: `markStart` is the settled height (40), not the floor (30). Marking below the
    /// settled height would hand the redeemer pool appreciation earned after their principal
    /// stopped earning, which the design excludes; the floor only ever raises `markStart`.
    function testMarkStartPrefersSettledHeightOverFloor() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        // a pre-upgrade request, pinned as the floor at 30
        uint32 legacy = _openRequest(user, 30e18);
        _stripAnchor(legacy);
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 30e18);

        // post-upgrade demand extends the axis to 50
        uint32 fresh = _openRequest(user, 20e18);
        assertEq(redeemManager.getRedeemRequestDetails(fresh).height, 30e18);

        // one withdrawal event settles 40 LsETH: the legacy 30 plus the first 10 of the fresh request
        _reportRate(1.05e18);
        _reportWithdraw(40e18, 1.05e18);
        assertEq(_settledHeight(), 40e18);
        assertGt(_settledHeight(), redeemManager.getRateMarkFloor());

        // 10 LsETH stops earning at 1.05. markStart == max(cursor 0, settled 40, floor 30) == 40
        _reportStoppedEarning(applyRate(10e18, 1.05e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 40e18);
        assertEq(mark.amount, 10e18);
        assertEq(mark.markedEth, applyRate(10e18, 1.05e18));

        // the fresh request straddles the mark boundary: [30, 40) is a gap, [40, 50) is marked
        // first fill, against the 40 LsETH event: 10 LsETH in the gap, capped at the request rate
        assertEq(_claim(fresh), 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(fresh).height, 40e18);
        // the remaining 10 LsETH sits under the mark and is paid at the locked 1.05 rate
        assertEq(_settleAndClaim(fresh, 10e18, 1.05e18), applyRate(10e18, 1.05e18));
    }

    /// Scenario: a pre-upgrade request is partially claimed BEFORE the upgrade at a settlement rate
    /// below its request rate, then the residual is claimed AFTER the upgrade against a post-upgrade
    /// withdrawal event, with rate marks live above the floor.
    /// Expected: unchanged legacy semantics. The residual is capped pro-rata on the surviving
    /// `maxRedeemableEth`, and the marks are ignored because the anchor is zero.
    /// @dev Cross-reference `testPartialClaimBelowRequestRateDriftsImpliedCapRate`: the drifted
    ///      implied cap rate is exactly why `RedeemRequestAnchor` exists. Here 100 LsETH quoted at
    ///      1.0 is 99% settled at 0.5, leaving a 50.5 ETH budget against 1 LsETH of size — an implied
    ///      ceiling of 50.5 ETH per LsETH. The legacy formula therefore lets the residual absorb the
    ///      full 1.2 ETH the post-upgrade event prices it at, where the anchored path would have
    ///      capped it at the 1.0 ETH request value and buffered the 0.2 ETH difference (see
    ///      `testRequestBetweenV1_2AndV1_3HasAnchorButCannotBeMarked`, the same shape with an anchor).
    function testLegacyRequestPartiallyClaimedAcrossUpgradeKeepsDriftedCap() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        // 100 LsETH quoted at 1.0, made to look pre-upgrade by clearing its anchor
        uint32 legacy = _openRequest(user, 100e18);
        _stripAnchor(legacy);
        assertEq(redeemManager.getRedeemRequestAnchor(legacy).lsETHAtRequest, 0);

        // 99 of the 100 LsETH settles at half the request rate: 49.5 ETH paid against a 99 ETH cap
        _reportRate(0.5e18);
        assertEq(_settleAndClaim(legacy, 99e18, 0.5e18), 49.5e18);
        RedeemQueueV2.RedeemRequest memory residual = redeemManager.getRedeemRequestDetails(legacy);
        assertEq(residual.height, 99e18);
        assertEq(residual.amount, 1e18);
        // 100 ETH budget minus 49.5 ETH paid, against 1 LsETH: the implied ceiling has drifted to 50.5
        assertEq(residual.maxRedeemableEth, 50.5e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // the upgrade reads the residual's END position, not its live height: 99 + 1 == 100
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 100e18);

        // a post-upgrade cohort, and a mark that covers it and only it
        _reportRate(1e18);
        uint32 fresh = _openRequest(user, 10e18);
        _reportRate(1.2e18);
        _reportStoppedEarning(applyRate(10e18, 1.2e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 100e18);
        assertEq(mark.amount, 10e18);
        // the legacy residual occupies [99, 100) and so lies strictly below every mark
        assertGe(mark.height, residual.height + residual.amount);

        // the residual now settles at 1.2 against a post-upgrade event
        // legacy cap == 1 LsETH * 50.5 ETH / 1 LsETH == 50.5 ETH, so nothing binds: the full 1.2 ETH is paid
        assertEq(_settleAndClaim(legacy, 1e18, 1.2e18), 1.2e18);
        // no ETH was diverted: the anchored path would have capped at 1.0 ETH and buffered 0.2 ETH
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(redeemManager.getRedeemRequestDetails(legacy).amount, 0);
        // and the fresh request is untouched by any of it: it still holds the whole mark
        assertEq(_settleAndClaim(fresh, 10e18, 1.2e18), applyRate(10e18, 1.2e18));
    }

    /// Scenario: a stopped-earning delta is reported while the only pending demand is pre-upgrade —
    /// the first oracle report after the upgrade, before any new request has arrived.
    /// Expected: `markable == 0`, so `StoppedEarningExceededMarkableDemand(reported, 0)` is emitted
    /// and `reportStoppedEarning` returns without pushing a mark. The credit is DISCARDED
    /// PERMANENTLY: there is no carry-forward buffer, so the post-upgrade request that arrives one
    /// block later is paid at its own request rate and sees nothing of it.
    /// @dev This is the sharpest edge of the cutover. The ETH is not lost to the protocol — it stays
    ///      in River and therefore accrues to the remaining LsETH holders, raising the pool rate for
    ///      everyone who did NOT redeem. It simply never reaches any redeemer. Whether that is the
    ///      intended distribution is a product question; the mechanism is asserted here so the
    ///      behaviour cannot change silently.
    function testStoppedEarningWithOnlyLegacyDemandIsDiscardedPermanently() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        // the entire queue is pre-upgrade demand, so the floor lands on top of it
        uint32 legacy = _openRequest(user, 30e18);
        _stripAnchor(legacy);
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 30e18);

        // 30 LsETH of principal stops earning at 1.05, worth 31.5 ETH. markStart == floor == 30 and
        // totalRequestedHeight == 30, so markable == 0 and the whole report is clamped away
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(30e18, 0);
        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 0);

        // the first post-upgrade cohort arrives immediately afterwards, quoted at the new 1.05 rate
        uint32 fresh = _openRequest(user, 30e18);
        assertEq(redeemManager.getRedeemRequestAnchor(fresh).lsETHAtRequest, 30e18);
        assertEq(redeemManager.getRedeemRequestAnchor(fresh).ethAtRequest, 31.5e18);
        // nothing was carried forward: the stack is still empty
        assertEq(redeemManager.getRateMarkCount(), 0);

        // both settle at an appreciated 1.10, which would price 30 LsETH at 33 ETH
        _reportRate(1.1e18);
        // the legacy request is capped at its 1.0 request rate: 30 ETH paid, 3 ETH buffered
        assertEq(_settleAndClaim(legacy, 30e18, 1.1e18), 30e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 3e18);
        // and the fresh request at its own 1.05 request rate, NOT at any inherited mark rate:
        // 31.5 ETH paid, 1.5 ETH buffered. Had the discarded credit carried forward, a mark over
        // [30, 60) would have raised this cap and the payout with it.
        assertEq(_settleAndClaim(fresh, 30e18, 1.1e18), 31.5e18);

        // 3 + 1.5 ETH of settlement value was redirected to the exceeding-eth buffer, which River pulls
        // back on the next report: it ends up with the LsETH holders who stayed, not with either
        // redeemer. The report that funded the second settlement already collected the first 3 ETH, so
        // what is staged here is the 1.5 ETH from the claim that followed it.
        assertEq(redeemManager.getBufferedExceedingEth(), 1.5e18);
        _reportRate(1.1e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0, "River must reclaim the whole confiscated surplus");
    }

    /// Scenario: `initializeRedeemManagerV1_3` runs against a queue whose tail has been garbled by a
    /// re-run of the V1_2 migration over an already-V2 queue. `_redeemQueueMigrationV1_2` reads the
    /// array through the 4-word V1 struct and writes it back through the 5-word V2 struct, so from
    /// element 1 onward every field is read from the wrong offset: element 1's `amount` picks up
    /// element 0's `initiator`, and its `height` picks up element 1's own `recipient`. Both become
    /// address-shaped integers. This happened on Hoodi (ids 0-85 garbled at block 3027299).
    /// Expected: the initializer inspects the LAST element and nothing else, so it pins the floor at
    /// the garbled end position instead of the real one — no sanity check, no revert.
    /// @dev FINDING (Informational, upgrade safety): `initializeRedeemManagerV1_3` derives the
    ///      cutover from `redeemRequests[length - 1].height + .amount` alone. A garbled tail
    ///      therefore mis-pins the floor silently, to an address-shaped nonsense value ~1e48 here.
    ///      `reportStoppedEarning` computes `totalRequestedHeight` from the very same element, so the
    ///      two cancel and `markable` is 0 for every genuinely-pending request: stopped-earning
    ///      accrual is permanently dead for the whole existing queue, with only the
    ///      `StoppedEarningExceededMarkableDemand` event to show for it. This is a consequence of the
    ///      pre-existing V1_2 corruption rather than a new defect, but the initializer is the last
    ///      place it could have been caught. Recommendation: assert the tail's end position against
    ///      an expected total supplied as a parameter, or against `RedeemDemand` plus the settled
    ///      height, before pinning.
    function testInitializeV1_3OnCorruptedQueuePinsNonsenseFloor() external {
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);
        _reportRate(1e18);

        uint32 first = _openRequest(userA, 30e18);
        uint32 second = _openRequest(userB, 20e18);
        // the honest end of the queue, which the floor should have landed on
        assertEq(
            redeemManager.getRedeemRequestDetails(second).height + redeemManager.getRedeemRequestDetails(second).amount,
            50e18
        );

        // reproduce the stride-mismatch garble on the LAST element: word 0 (amount) takes element 0's
        // initiator, word 3 (height) takes element 1's own recipient
        uint256 garbledAmount = uint256(uint160(redeemManager.getRedeemRequestDetails(first).initiator));
        uint256 garbledHeight = uint256(uint160(redeemManager.getRedeemRequestDetails(second).recipient));
        vm.store(address(redeemManager), _queueSlot(second, 0), bytes32(garbledAmount));
        vm.store(address(redeemManager), _queueSlot(second, 3), bytes32(garbledHeight));

        // the floor is whatever the garbled tail claims its end position is
        uint256 expectedFloor = garbledHeight + garbledAmount;
        _pokeVersionTo(2);
        vm.expectEmit(true, true, true, true);
        emit SetRateMarkFloor(expectedFloor);
        redeemManager.initializeRedeemManagerV1_3();
        assertEq(redeemManager.getRateMarkFloor(), expectedFloor);
        // ...which is not 50e18, and is an address-scaled number rather than an LsETH amount
        assertTrue(expectedFloor != 50e18);
        assertGt(expectedFloor, 1e30);

        // consequence 1: the existing queue can never be marked again. `markStart` is the floor and
        // `totalRequestedHeight` is the same garbled sum, so `markable` is 0 on every report.
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(10e18, 0);
        _reportStoppedEarning(applyRate(10e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 0);

        // consequence 2: marking "resumes" only above the garbled tail, because a new request appends
        // at the corrupt end position
        _reportRate(1e18);
        uint32 fresh = _openRequest(userA, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(fresh).height, expectedFloor);
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(10e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).height, expectedFloor);
        assertEq(redeemManager.getRateMarkDetails(0).amount, 10e18);

        // ...and that region of the axis is unreachable: withdrawal events are positioned by
        // cumulative settled LsETH, which can never climb to ~1e48, so the request stays unsatisfied
        _reportRate(1e18);
        _reportWithdraw(50e18, 1e18);
        assertEq(_settledHeight(), 50e18);
        uint32[] memory ids = new uint32[](1);
        ids[0] = fresh;
        assertEq(redeemManager.resolveRedeemRequests(ids)[0], -1);
    }

    /// Scenario: a request opened in the window BETWEEN the V1_2 and V1_3 upgrades — version already
    /// at 2, `initializeRedeemManagerV1_3` not yet run.
    /// Expected: it DOES carry an anchor, because the anchor is written by `_requestRedeem` and not
    /// by the V1_3 initializer, which only pins the floor. But the floor is then pinned at that
    /// request's own end position, so no mark can ever cover it.
    /// @dev The asymmetry: this request has an anchor yet behaves like legacy demand. It is not
    ///      identical to legacy demand though, and the difference is visible on a partial claim. The
    ///      legacy path caps the residual pro-rata on the DECREMENTING `maxRedeemableEth`, whose
    ///      implied rate drifts upward after a fill below the request rate (see
    ///      `testLegacyRequestPartiallyClaimedAcrossUpgradeKeepsDriftedCap`, where the residual
    ///      absorbs 1.2 ETH). The anchored path recomputes the cap from the immutable request-time
    ///      pair, so the same residual is held at 1.0 ETH and the surplus is buffered.
    function testRequestBetweenV1_2AndV1_3HasAnchorButCannotBeMarked() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        // the deployment is at V1_2; the V1_3 initializer has not run yet
        _pokeVersionTo(2);
        uint32 id = _openRequest(user, 30e18);

        // the anchor is written by _requestRedeem, so this request has one
        assertEq(redeemManager.getRedeemRequestAnchor(id).lsETHAtRequest, 30e18);
        assertEq(redeemManager.getRedeemRequestAnchor(id).ethAtRequest, 30e18);

        // ...and then the floor is pinned on top of it, at its own end position
        vm.expectEmit(true, true, true, true);
        emit SetRateMarkFloor(30e18);
        redeemManager.initializeRedeemManagerV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 30e18);
        assertEq(
            redeemManager.getRateMarkFloor(),
            redeemManager.getRedeemRequestDetails(id).height + redeemManager.getRedeemRequestDetails(id).amount
        );

        // so it can never be marked: markable == totalRequestedHeight (30) - markStart (30) == 0
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(30e18, 0);
        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 0);

        // 29 of the 30 LsETH settles at half the request rate: 14.5 ETH against a 29 ETH slice cap
        _reportRate(0.5e18);
        assertEq(_settleAndClaim(id, 29e18, 0.5e18), 14.5e18);
        RedeemQueueV2.RedeemRequest memory residual = redeemManager.getRedeemRequestDetails(id);
        assertEq(residual.height, 29e18);
        assertEq(residual.amount, 1e18);
        // the legacy budget has drifted to an implied 15.5 ETH per LsETH, exactly as it would for a
        // request with no anchor
        assertEq(residual.maxRedeemableEth, 15.5e18);

        // the residual settles at 1.2, which prices 1 LsETH at 1.2 ETH. The anchor holds the cap at
        // the request-time 1.0 ETH regardless of the drifted budget, so 0.2 ETH is buffered — where
        // the zero-anchor request of the previous test would have kept the whole 1.2 ETH
        _reportRate(1.2e18);
        assertEq(_settleAndClaim(id, 1e18, 1.2e18), 1e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0.2e18);
    }
}
