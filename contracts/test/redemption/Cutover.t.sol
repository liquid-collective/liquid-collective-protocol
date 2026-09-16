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
    /// @dev Returns the raw storage slot for a word within a queue element.
    function _queueSlot(uint256 index, uint256 word) internal pure returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encode(REDEEM_QUEUE_ID_SLOT))) + (index * 5) + word);
    }

    /// Verifies that initialization derives the floor from the tail request's invariant end position
    /// even when the pre-upgrade queue is fully claimed.
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

    /// Verifies that the settled height takes precedence over a lower floor when selecting the mark
    /// start, preventing already-settled demand from being marked.
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

    /// Verifies that a partially claimed legacy request retains its drifted pro-rata cap after the
    /// upgrade and ignores post-upgrade marks because it has no anchor.
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
        // markStart is the settled height, 99, so the unsettled [99, 100) wei of legacy demand still
        // sits below the floor: 1 of the 10 reported is funding it and is clipped, leaving 9 to mark
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningBelowRateMarkFloor(10e18, 1e18, 100e18);
        _reportStoppedEarning(applyRate(10e18, 1.2e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 100e18);
        assertEq(mark.amount, 9e18);
        // the eth leg scales with the clip, so the locked rate is still the 1.2 the pool held
        assertEq(mark.markedEth, applyRate(9e18, 1.2e18));
        // the legacy residual occupies [99, 100), strictly below every mark
        assertGe(mark.height, residual.height + residual.amount);

        // the legacy cap of 50.5 ETH does not bind, so the full 1.2 is paid where the anchored path
        // would have capped at 1.0 and buffered 0.2
        assertEq(_settleAndClaim(legacy, 1e18, 1.2e18), 1.2e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(redeemManager.getRedeemRequestDetails(legacy).amount, 0);

        // the fresh request spans [100, 110) but the clipped mark only covers [100, 109): 9 LsETH is
        // valued at the locked 1.2 (10.8) and the uncovered 1 at its request-time 1.0, for an 11.8 cap
        // against the event's 12 -- the clipped wei of headroom is what the legacy residual consumed
        assertEq(_settleAndClaim(fresh, 10e18, 1.2e18), 11.8e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0.2e18);
    }

    /// Verifies that stopped-earning credit for legacy-only demand is clipped below the floor and is
    /// not carried forward to later post-upgrade requests.
    function testStoppedEarningWithOnlyLegacyDemandIsDiscardedPermanently() external {
        address user = _generateAllowlistedUser(0);
        _reportRate(1e18);

        uint32 legacy = _openRequest(user, 30e18);
        _stripAnchor(legacy);
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 30e18);

        // the whole reported slice sits below the floor, so it is clipped out rather than relocated:
        // `lsETHToMark` is 0 and no mark is pushed. `markable` is also 0 (markStart == floor == 30 ==
        // totalRequestedHeight), but the clip returns first, so only the floor event fires.
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningBelowRateMarkFloor(30e18, 30e18, 30e18);
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

    /// Verifies that initialization trusts a corrupted queue tail without validation, producing an
    /// unreachable floor that prevents both existing and future demand from being marked.
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

        // never markable again: every reported slice is clipped away as below-floor, since the floor
        // sits ~1e48 above the settled height
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningBelowRateMarkFloor(10e18, 10e18, expectedFloor);
        _reportStoppedEarning(applyRate(10e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 0);

        // and appending fresh demand above the garbled tail does not revive it. `markStart` is
        // `max(cursor, settledHeight)`, both of which are bounded by what settlement actually reaches,
        // so it can never climb to the floor -- the clip consumes every report before `markable` (which
        // is a genuine 10e18 here) is ever consulted
        _reportRate(1e18);
        uint32 fresh = _openRequest(userA, 10e18);
        assertEq(redeemManager.getRedeemRequestDetails(fresh).height, expectedFloor);
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningBelowRateMarkFloor(10e18, 10e18, expectedFloor);
        _reportStoppedEarning(applyRate(10e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 0, "a garbled floor kills marking for good");

        // ...and that region is unreachable: events are positioned by cumulative settled LsETH, which
        // can never climb to ~1e48, so the request stays unsatisfied
        _reportRate(1e18);
        _reportWithdraw(50e18, 1e18);
        assertEq(_settledHeight(), 50e18);
        uint32[] memory ids = new uint32[](1);
        ids[0] = fresh;
        assertEq(redeemManager.resolveRedeemRequests(ids)[0], -1);
    }

    /// Verifies that a request opened between upgrades receives an anchor but remains below the new
    /// floor, so it cannot be marked and its carry reproduces legacy cap behavior.
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

        // never markable: the request's whole span sits below the floor, so the slice is clipped away
        // before `markable` (totalRequestedHeight 30 - markStart 30 == 0) is even reached
        _reportRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit StoppedEarningBelowRateMarkFloor(30e18, 30e18, 30e18);
        _reportStoppedEarning(applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getRateMarkCount(), 0);

        // 29 of the 30 settles at half the request rate: 14.5 against a 29 ETH slice cap
        _reportRate(0.5e18);
        assertEq(_settleAndClaim(id, 29e18, 0.5e18), 14.5e18);
        RedeemQueueV2.RedeemRequest memory residual = redeemManager.getRedeemRequestDetails(id);
        assertEq(residual.height, 29e18);
        assertEq(residual.amount, 1e18);
        // the anchored path leaves the request-time budget field untouched -- it is superseded by the
        // anchor, and the unspent cap is recorded in `RedeemRequestCarry` instead of drifting in place
        assertEq(residual.maxRedeemableEth, 30e18);
        assertEq(redeemManager.getRedeemRequestCarry(id), 14.5e18, "the 29 ETH cap spent only 14.5");

        // the carry reproduces the legacy drift exactly: a 1 ETH slice cap plus 14.5 carried is the
        // same 15.5 ceiling the decrementing budget of the previous test arrives at, so the whole 1.2
        // is paid and nothing is buffered
        _reportRate(1.2e18);
        assertEq(_settleAndClaim(id, 1e18, 1.2e18), 1.2e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        // fully claimed, so the carry is cleared rather than left claimable by a later event
        assertEq(redeemManager.getRedeemRequestCarry(id), 0);
    }
}
