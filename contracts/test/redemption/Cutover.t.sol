//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionReportBase.sol";

/// @title Stopped-earning launch cutover tests
/// @notice Covers `initializeRedeemManagerV1_3` and the boundary it draws between pre-upgrade demand
///         and the first post-upgrade cohort.
/// @dev Two independent mechanisms enforce the cutover, and they are easy to conflate:
///        1. a zero `RedeemRequestAnchor` makes a request ignore rate marks, capping it by the legacy
///           pro-rata formula on the decrementing `maxRedeemableEth`;
///        2. the `RateMarkFloor` stops pre-upgrade demand from consuming marks, which matters because
///           marks advance a single cursor across the queue -- without it the first reports after the
///           upgrade would spend their credit on requests that cannot use it.
///      This suite pins the seams: the floor derivation (B4, B11, B12), its interaction with the
///      settled height (B5), and the two ways a request ends up excluded from marking -- no anchor
///      (B7, B8) or an anchor the floor sits above (B12).
contract RedemptionCutoverTests is RedemptionReportBase {
    /// @dev Storage slot of `word` of queue element `index`: a dynamic array at a raw keccak slot,
    ///      stride 5 -- amount, maxRedeemableEth, recipient, height, initiator.
    function _queueSlot(uint256 index, uint256 word) internal pure returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encode(REDEEM_QUEUE_ID_SLOT))) + (index * 5) + word);
    }

    /// Scenario: the whole pre-upgrade queue has been claimed to the last wei, so every request
    /// carries `amount == 0` and a `height` advanced to its own end position.
    /// Expected: the floor still lands on the true end of the queue, since `height + amount` is
    /// invariant across a request's lifetime.
    function testInitializeV1_3OnFullyClaimedQueuePinsFloorAtTotalRequested() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        uint32 first = _openRequest(user, 30e18);
        uint32 second = _openRequest(user, 20e18);
        _stripAnchor(first);
        _stripAnchor(second);

        _reportWithdraw(50e18, 1e18);
        assertEq(_claim(first), 30e18);
        assertEq(_claim(second), 20e18);

        assertEq(redeemManager.getRedeemRequestDetails(first).amount, 0);
        assertEq(redeemManager.getRedeemRequestDetails(first).height, 30e18);
        assertEq(redeemManager.getRedeemRequestDetails(second).amount, 0);
        assertEq(redeemManager.getRedeemRequestDetails(second).height, 50e18);

        _pokeVersionTo(2);
        vm.expectEmit(true, true, true, true);
        emit SetRateMarkFloor(50e18);
        redeemManager.initializeRedeemManagerV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 50e18);

        uint32 fresh = _openRequest(user, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(fresh).height, 50e18);

        _reportRate(1.1e18);
        _reportStoppedEarning(applyRate(10e18, 1.1e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 50e18);
        assertEq(mark.amount, 10e18);
        assertEq(mark.markedEth, 11e18);

        assertEq(_settleAndClaim(fresh, 10e18, 1.1e18), 11e18);
    }

    /// Scenario: `reportStoppedEarning` runs while the settled height sits above the floor. Not
    /// orderable that way at upgrade time -- `RedeemDemand` keeps cumulative withdrawals below
    /// cumulative requests -- but once post-upgrade demand extends the queue, events settle past the
    /// old queue end.
    /// Expected: `markStart` is the settled height (40), not the floor (30). Marking below the settled
    /// height would hand the redeemer appreciation earned after their principal stopped earning; the
    /// floor only ever raises `markStart`.
    function testMarkStartPrefersSettledHeightOverFloor() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        uint32 legacy = _openRequest(user, 30e18);
        _stripAnchor(legacy);
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 30e18);

        uint32 fresh = _openRequest(user, 20e18);
        assertEq(redeemManager.getRedeemRequestDetails(fresh).height, 30e18);

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

        // the fresh request straddles the boundary: [30, 40) is a gap, [40, 50) is marked, so the
        // first fill takes the gap at the request rate
        assertEq(_claim(fresh), 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(fresh).height, 40e18);
        assertEq(_settleAndClaim(fresh, 10e18, 1.05e18), applyRate(10e18, 1.05e18));
    }

    /// Scenario: a pre-upgrade request partially claimed before the upgrade at a settlement rate below
    /// its request rate, then the residual claimed afterwards with rate marks live above the floor.
    /// Expected: unchanged legacy semantics -- the residual capped pro-rata on the surviving
    /// `maxRedeemableEth`, with the marks ignored because the anchor is zero.
    /// @dev The drifted implied cap rate is why `RedeemRequestAnchor` exists. Here 100 LsETH quoted at
    ///      1.0 is 99% settled at 0.5, leaving a 50.5 ETH budget against 1 LsETH, so the legacy formula
    ///      lets the residual absorb the full 1.2 ETH the post-upgrade event prices it at. See
    ///      `testRequestBetweenV1_2AndV1_3HasAnchorButCannotBeMarked` for the same shape with an
    ///      anchor, and `testPartialClaimBelowRequestRateDriftsImpliedCapRate` for the drift itself.
    function testLegacyRequestPartiallyClaimedAcrossUpgradeKeepsDriftedCap() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        uint32 legacy = _openRequest(user, 100e18);
        _stripAnchor(legacy);
        assertEq(redeemManager.getRedeemRequestAnchor(legacy).lsETHAtRequest, 0);

        // 99 of the 100 settles at half the request rate: 49.5 paid against a 99 ETH cap
        _reportRate(0.5e18);
        assertEq(_settleAndClaim(legacy, 99e18, 0.5e18), 49.5e18);
        RedeemQueueV2.RedeemRequest memory residual = redeemManager.getRedeemRequestDetails(legacy);
        assertEq(residual.height, 99e18);
        assertEq(residual.amount, 1e18);
        // 100 budget minus 49.5 paid against 1 LsETH: the implied ceiling has drifted to 50.5
        assertEq(residual.maxRedeemableEth, 50.5e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // the upgrade reads the residual's END position, not its live height: 99 + 1 == 100
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 100e18);

        _reportRate(1e18);
        uint32 fresh = _openRequest(user, 10e18);
        _reportRate(1.2e18);
        _reportStoppedEarning(applyRate(10e18, 1.2e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 100e18);
        assertEq(mark.amount, 10e18);
        // the legacy residual occupies [99, 100), strictly below every mark
        assertGe(mark.height, residual.height + residual.amount);

        // the legacy cap of 50.5 ETH does not bind, so the full 1.2 is paid where the anchored path
        // would have capped at 1.0 and buffered 0.2
        assertEq(_settleAndClaim(legacy, 1e18, 1.2e18), 1.2e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(redeemManager.getRedeemRequestDetails(legacy).amount, 0);
        assertEq(_settleAndClaim(fresh, 10e18, 1.2e18), applyRate(10e18, 1.2e18));
    }

    /// Scenario: a stopped-earning delta reported while the only pending demand is pre-upgrade -- the
    /// first report after the upgrade, before any new request arrives.
    /// Expected: `markable == 0`, so `StoppedEarningExceededMarkableDemand(reported, 0)` is emitted and
    /// no mark pushed. With no carry-forward buffer the credit is discarded permanently, and the
    /// post-upgrade request arriving a block later sees nothing of it.
    /// @dev The ETH is not lost to the protocol -- it accrues to the holders who did not redeem, raising
    ///      the pool rate for them -- it simply never reaches any redeemer. Asserted so that
    ///      distribution cannot change silently.
    function testStoppedEarningWithOnlyLegacyDemandIsDiscardedPermanently() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        uint32 legacy = _openRequest(user, 30e18);
        _stripAnchor(legacy);
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 30e18);

        // markStart == floor == 30 == totalRequestedHeight, so markable == 0 and the report is
        // clamped away entirely
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(30e18, 0);
        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 0);

        uint32 fresh = _openRequest(user, 30e18);
        assertEq(redeemManager.getRedeemRequestAnchor(fresh).lsETHAtRequest, 30e18);
        assertEq(redeemManager.getRedeemRequestAnchor(fresh).ethAtRequest, 31.5e18);
        assertEq(redeemManager.getRateMarkCount(), 0);

        _reportRate(1.1e18);
        // the legacy request is capped at its 1.0: 30 paid, 3 buffered
        assertEq(_settleAndClaim(legacy, 30e18, 1.1e18), 30e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 3e18);
        // and the fresh request at its own 1.05: had the discarded credit carried forward, a mark over
        // [30, 60) would have raised this cap and the payout
        assertEq(_settleAndClaim(fresh, 30e18, 1.1e18), 31.5e18);

        // 3 + 1.5 ETH went to the holders who stayed rather than to either redeemer, of which the
        // report funding the second settlement already collected the first 3
        assertEq(redeemManager.getBufferedExceedingEth(), 1.5e18);
        _reportRate(1.1e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0, "River must reclaim the whole confiscated surplus");
    }

    /// Scenario: `initializeRedeemManagerV1_3` runs against a queue whose tail was garbled by a re-run
    /// of the V1_2 migration over an already-V2 queue: `_redeemQueueMigrationV1_2` reads through the
    /// 4-word V1 struct and writes back through the 5-word V2 struct, so from element 1 onward every
    /// field comes from the wrong offset -- element 1's `amount` picks up element 0's `initiator` and
    /// its `height` its own `recipient`, both becoming address-shaped integers. This happened on Hoodi
    /// (ids 0-85 garbled at block 3027299).
    /// Expected: the initializer inspects the last element and nothing else, pinning the floor at the
    /// garbled end position -- no sanity check, no revert.
    ///
    /// @dev FINDING (Informational, upgrade safety)
    ///      Claim: `initializeRedeemManagerV1_3` derives the cutover from
    ///        `redeemRequests[length - 1].height + .amount` alone, so a garbled tail mis-pins the
    ///        floor silently -- to ~1e48 here.
    ///      Mechanism: `reportStoppedEarning` computes `totalRequestedHeight` from the same element,
    ///        so the two cancel and `markable` is 0 for every genuinely-pending request. Stopped-
    ///        earning accrual is permanently dead for the existing queue, with only the
    ///        `StoppedEarningExceededMarkableDemand` event to show for it.
    ///      Reachability: a consequence of the pre-existing V1_2 corruption rather than a new defect,
    ///        but the initializer is the last place it could have been caught.
    ///      Recommendation: assert the tail's end position against an expected total passed as a
    ///        parameter, or against `RedeemDemand` plus the settled height, before pinning.
    function testInitializeV1_3OnCorruptedQueuePinsNonsenseFloor() external {
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);
        _reportRate(1e18);

        uint32 first = _openRequest(userA, 30e18);
        uint32 second = _openRequest(userB, 20e18);
        assertEq(
            redeemManager.getRedeemRequestDetails(second).height + redeemManager.getRedeemRequestDetails(second).amount,
            50e18
        );

        // the stride-mismatch garble on the LAST element: word 0 (amount) takes element 0's initiator,
        // word 3 (height) takes element 1's own recipient
        uint256 garbledAmount = uint256(uint160(redeemManager.getRedeemRequestDetails(first).initiator));
        uint256 garbledHeight = uint256(uint160(redeemManager.getRedeemRequestDetails(second).recipient));
        vm.store(address(redeemManager), _queueSlot(second, 0), bytes32(garbledAmount));
        vm.store(address(redeemManager), _queueSlot(second, 3), bytes32(garbledHeight));

        uint256 expectedFloor = garbledHeight + garbledAmount;
        _pokeVersionTo(2);
        vm.expectEmit(true, true, true, true);
        emit SetRateMarkFloor(expectedFloor);
        redeemManager.initializeRedeemManagerV1_3();
        assertEq(redeemManager.getRateMarkFloor(), expectedFloor);
        // ...an address-scaled number rather than an LsETH amount
        assertTrue(expectedFloor != 50e18);
        assertGt(expectedFloor, 1e30);

        // never markable again: `markStart` is the floor and `totalRequestedHeight` the same garbled
        // sum, so `markable` is 0 on every report
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(10e18, 0);
        _reportStoppedEarning(applyRate(10e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 0);

        // marking resumes only above the garbled tail, where a new request appends
        _reportRate(1e18);
        uint32 fresh = _openRequest(userA, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(fresh).height, expectedFloor);
        _reportRate(1.05e18);
        _reportStoppedEarning(applyRate(10e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 1);
        assertEq(redeemManager.getRateMarkDetails(0).height, expectedFloor);
        assertEq(redeemManager.getRateMarkDetails(0).amount, 10e18);

        // ...and that region is unreachable: events are positioned by cumulative settled LsETH, which
        // can never climb to ~1e48, so the request stays unsatisfied
        _reportRate(1e18);
        _reportWithdraw(50e18, 1e18);
        assertEq(_settledHeight(), 50e18);
        uint32[] memory ids = new uint32[](1);
        ids[0] = fresh;
        assertEq(redeemManager.resolveRedeemRequests(ids)[0], -1);
    }

    /// Scenario: a request opened between the V1_2 and V1_3 upgrades -- version already at 2,
    /// `initializeRedeemManagerV1_3` not yet run.
    /// Expected: it does carry an anchor, written by `_requestRedeem` rather than by the V1_3
    /// initializer, which only pins the floor -- but the floor then lands on that request's own end
    /// position, so no mark can ever cover it.
    /// @dev An anchor yet legacy-like behaviour, though not identically: the legacy path caps the
    ///      residual on the decrementing `maxRedeemableEth`, whose implied rate drifts up after a fill
    ///      below the request rate (see `testLegacyRequestPartiallyClaimedAcrossUpgradeKeepsDriftedCap`),
    ///      where the anchored path recomputes from the immutable request-time pair and buffers the
    ///      surplus.
    function testRequestBetweenV1_2AndV1_3HasAnchorButCannotBeMarked() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        _pokeVersionTo(2);
        uint32 id = _openRequest(user, 30e18);

        assertEq(redeemManager.getRedeemRequestAnchor(id).lsETHAtRequest, 30e18);
        assertEq(redeemManager.getRedeemRequestAnchor(id).ethAtRequest, 30e18);

        vm.expectEmit(true, true, true, true);
        emit SetRateMarkFloor(30e18);
        redeemManager.initializeRedeemManagerV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 30e18);
        assertEq(
            redeemManager.getRateMarkFloor(),
            redeemManager.getRedeemRequestDetails(id).height + redeemManager.getRedeemRequestDetails(id).amount
        );

        // never markable: markable == totalRequestedHeight (30) - markStart (30) == 0
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningExceededMarkableDemand(30e18, 0);
        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 0);

        // 29 of the 30 settles at half the request rate: 14.5 against a 29 ETH slice cap
        _reportRate(0.5e18);
        assertEq(_settleAndClaim(id, 29e18, 0.5e18), 14.5e18);
        RedeemQueueV2.RedeemRequest memory residual = redeemManager.getRedeemRequestDetails(id);
        assertEq(residual.height, 29e18);
        assertEq(residual.amount, 1e18);
        // the budget has drifted to an implied 15.5 ETH per LsETH, as it would with no anchor
        assertEq(residual.maxRedeemableEth, 15.5e18);

        // the anchor holds the cap at the request-time 1.0 regardless of the drifted budget, so 0.2 is
        // buffered where the zero-anchor request of the previous test kept the whole 1.2
        _reportRate(1.2e18);
        assertEq(_settleAndClaim(id, 1e18, 1.2e18), 1e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0.2e18);
    }
}
