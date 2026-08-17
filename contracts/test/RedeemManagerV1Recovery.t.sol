//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedeemManager.1.t.sol";
import "../src/migration/RedeemManagerV1Recovery.sol";

/// @title Recovery implementation with the pre-guard migration exposed
/// @notice `initializeRedeemManagerV1_2` now refuses to run against a queue already in the V2 layout,
///         so these tests use the unguarded path to recreate the corrupted state before repairing it.
///         The `init(1)` bump matches what happened on staging, leaving Version at 2 so the repair's
///         `init(2)` guard is satisfied.
contract RedeemManagerV1RecoveryHarness is RedeemManagerV1Recovery {
    /// @notice Replay the V1 to V2 migration without the layout guard
    function sudoReplayMigrationUnguarded() external init(1) {
        _redeemQueueMigrationV1_2();
    }
}

/// @title Recovery tests for BS-4878
/// @notice Reproduces the staging state - a queue written natively in RedeemQueueV2 layout with Version
///         still at 1, so the replayed `initializeRedeemManagerV1_2` corrupts it - then repairs it and
///         asserts the queue is restored and claimable.
contract RedeemManagerV1RecoveryTest is RedeeManagerV1TestBase {
    RedeemManagerV1RecoveryHarness internal redeemManager;

    /// @notice Snapshot of the queue taken before the faulty migration runs
    RedeemQueueV2.RedeemRequest[] internal expected;

    function setUp() external {
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        allowlistDenier = makeAddr("allowlistDenier");
        redeemManager = new RedeemManagerV1RecoveryHarness();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(allowlistDenier);
        river = new RiverMock(address(allowlist));

        // The staging deploy script only ever calls this one, leaving Version at 1.
        redeemManager.initializeRedeemManagerV1(address(river));
    }

    function _allowlistUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.prank(allowlistAllower);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    function _request(uint256 _salt, uint256 _amount) internal returns (address user) {
        user = uf._new(_salt);
        _allowlistUser(user);
        river.sudoDeal(user, _amount);
        vm.startPrank(user);
        river.approve(address(redeemManager), _amount);
        redeemManager.requestRedeem(_amount, user);
        vm.stopPrank();
    }

    /// @notice Build a queue, partially claim one request so heights advance, then snapshot the truth
    function _seedQueue() internal {
        _request(1, 10 ether);
        _request(2, 20 ether);
        _request(3, 30 ether);
        _request(4, 40 ether);

        // A withdrawal event covering the first two requests plus half of the third, so request 2 ends up
        // partially claimed and its height moves forward - the case a naive repair would get wrong.
        vm.deal(address(this), 45 ether);
        river.sudoReportWithdraw{value: 45 ether}(address(redeemManager), 45 ether);

        uint32[] memory ids = new uint32[](1);
        uint32[] memory events = new uint32[](1);
        ids[0] = 2;
        events[0] = 0;
        redeemManager.claimRedeemRequests(ids, events);

        for (uint32 i = 0; i < 4; ++i) {
            expected.push(redeemManager.getRedeemRequestDetails(i));
        }
        // Requests sit at heights 0, 10, 30, 60. The 45 ether event covers request 2 up to 45, so half of
        // its 30 ether is settled and its height moves from 30 to 45 while its end position stays at 60.
        assertEq(expected[2].height, 45 ether, "request 2 height should have advanced");
        assertEq(expected[2].amount, 15 ether, "request 2 should be partially claimed");
    }

    function _corrupt() internal {
        redeemManager.sudoReplayMigrationUnguarded();
    }

    function _payload() internal view returns (RedeemQueueV2.RedeemRequest[] memory payload) {
        payload = new RedeemQueueV2.RedeemRequest[](expected.length);
        for (uint256 i = 0; i < expected.length; ++i) {
            payload[i] = expected[i];
        }
    }

    function testRepairRestoresEveryField() external {
        _seedQueue();
        _corrupt();

        // Sanity: the migration really did damage the queue.
        assertTrue(redeemManager.getRedeemRequestDetails(1).amount != expected[1].amount, "not corrupted");

        redeemManager.repairRedeemQueue(_payload());

        for (uint32 i = 0; i < expected.length; ++i) {
            RedeemQueueV2.RedeemRequest memory got = redeemManager.getRedeemRequestDetails(i);
            assertEq(got.amount, expected[i].amount, "amount");
            assertEq(got.maxRedeemableEth, expected[i].maxRedeemableEth, "maxRedeemableEth");
            assertEq(got.recipient, expected[i].recipient, "recipient");
            assertEq(got.height, expected[i].height, "height");
            assertEq(got.initiator, expected[i].initiator, "initiator");
        }
    }

    /// @notice After repair the remaining requests resolve and pay out exactly as they would have
    function testRepairedQueueIsClaimable() external {
        _seedQueue();
        _corrupt();
        redeemManager.repairRedeemQueue(_payload());

        // Cover the rest of the queue so every request can be settled.
        uint256 remaining = 100 ether - 45 ether;
        vm.deal(address(this), remaining);
        river.sudoReportWithdraw{value: remaining}(address(redeemManager), remaining);

        uint32[] memory ids = new uint32[](1);
        ids[0] = 0;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(ids);
        assertEq(resolved[0], 0, "request 0 should resolve to withdrawal event 0");

        address recipient = expected[0].recipient;
        uint256 before = recipient.balance;
        uint32[] memory events = new uint32[](1);
        events[0] = uint32(uint64(resolved[0]));
        redeemManager.claimRedeemRequests(ids, events);

        assertEq(recipient.balance - before, expected[0].maxRedeemableEth, "payout");
        assertEq(redeemManager.getRedeemRequestDetails(0).amount, 0, "request should be settled");
    }

    function testRepairIsOneShot() external {
        _seedQueue();
        _corrupt();
        redeemManager.repairRedeemQueue(_payload());

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector, 2, 3));
        redeemManager.repairRedeemQueue(_payload());
    }

    function testRepairRejectsWrongLength() external {
        _seedQueue();
        _corrupt();

        RedeemQueueV2.RedeemRequest[] memory short = new RedeemQueueV2.RedeemRequest[](3);
        for (uint256 i = 0; i < 3; ++i) {
            short[i] = expected[i];
        }

        vm.expectRevert(abi.encodeWithSelector(RedeemManagerV1Recovery.RepairLengthMismatch.selector, 3, 4));
        redeemManager.repairRedeemQueue(short);
    }

    function testRepairRejectsZeroRecipient() external {
        _seedQueue();
        _corrupt();

        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        payload[1].recipient = address(0);

        vm.expectRevert(abi.encodeWithSelector(RedeemManagerV1Recovery.RepairInvalidRecipient.selector, 1));
        redeemManager.repairRedeemQueue(payload);
    }

    /// @notice A request that starts before its predecessor ends is caught by the geometry checks
    function testRepairRejectsBrokenChain() external {
        _seedQueue();
        _corrupt();

        // Requests 0 and 1 span [0, 30). Dropping request 2 to height 1 makes it overlap them.
        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        payload[2].height = 1 ether;

        uint256 previousEnd = expected[1].height + expected[1].amount;
        vm.expectRevert(
            abi.encodeWithSelector(
                RedeemManagerV1Recovery.RepairOverlappingRequest.selector, 2, uint256(1 ether), previousEnd
            )
        );
        redeemManager.repairRedeemQueue(payload);
    }

    /// @notice The decisive check: a queue that is internally consistent but globally wrong is still rejected,
    ///         because RedeemDemand was never touched by the faulty migration
    function testRepairRejectsQueueInconsistentWithRedeemDemand() external {
        _seedQueue();
        _corrupt();

        // Inflate the final request. The chain stays monotonic, but the queue now ends in the wrong place.
        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        payload[3].amount += 1 ether;

        uint256 demand = redeemManager.getRedeemDemand();
        vm.expectRevert(
            abi.encodeWithSelector(RedeemManagerV1Recovery.RepairDemandMismatch.selector, demand + 1 ether, demand)
        );
        redeemManager.repairRedeemQueue(payload);
    }
}
