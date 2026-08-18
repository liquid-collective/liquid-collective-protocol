//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedeemManager.1.t.sol";
import "../src/migration/RedeemManagerV1Recovery.sol";

/// @title Recovery tests for BS-4878
/// @notice Reproduces the staging state - a queue written natively in RedeemQueueV2 layout with Version
///         still at 1, so the replayed `initializeRedeemManagerV1_2` corrupts it - then repairs it and
///         asserts the queue is restored and claimable.
contract RedeemManagerV1RecoveryTest is RedeeManagerV1TestBase {
    RedeemManagerV1Recovery internal redeemManager;

    /// @notice Snapshot of the queue taken before the faulty migration runs
    RedeemQueueV2.RedeemRequest[] internal expected;

    function setUp() external {
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        allowlistDenier = makeAddr("allowlistDenier");
        redeemManager = new RedeemManagerV1Recovery();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(allowlistDenier);
        river = new RiverMock(address(allowlist));

        // The staging deploy script only ever calls this one, leaving Version at 1.
        redeemManager.initializeRedeemManagerV1(address(river));

        // repairRedeemQueue is restricted to the EIP-1967 proxy admin. These tests drive the
        // implementation directly rather than through a proxy, so point that slot at this contract.
        vm.store(address(redeemManager), EIP1967_ADMIN_SLOT, bytes32(uint256(uint160(address(this)))));
    }

    bytes32 internal constant EIP1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /// @notice Mirrors of the recovery contract's events, declared here so `vm.expectEmit` can build them
    event RedeemRequestRepaired(
        uint32 indexed redeemRequestId,
        uint256 amount,
        uint256 maxRedeemableEth,
        address recipient,
        uint256 height,
        address initiator
    );
    event RedeemQueueRepairPerformed(uint256 count, uint256 queueEndPosition, uint256 redeemDemand);

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

    /// @notice Build a queue in which the first request is fully settled, so the payload carries a zero
    ///         amount record. 53 of the 125 real staging records are in exactly this shape, and their
    ///         height is the request's end position rather than its start.
    function _seedQueueWithSettledRequest() internal {
        _request(11, 10 ether);
        _request(12, 20 ether);
        _request(13, 30 ether);

        vm.deal(address(this), 30 ether);
        river.sudoReportWithdraw{value: 30 ether}(address(redeemManager), 30 ether);

        uint32[] memory ids = new uint32[](1);
        uint32[] memory events = new uint32[](1);
        redeemManager.claimRedeemRequests(ids, events);

        _snapshot(3);
        assertEq(expected[0].amount, 0, "request 0 should be fully settled");
        assertEq(expected[0].height, 10 ether, "a settled request sits at its own end position");
    }

    /// @notice Build a queue through the River path, so `initiator` differs from `recipient`. This is the
    ///         real staging shape: every legacy record was created via `River.requestRedeem`, so the
    ///         faulty migration's `initiator = recipient` overwrite is observable on every one of them.
    function _seedQueueViaRiver() internal returns (address[] memory recipients) {
        recipients = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 10 ether;
        amounts[1] = 20 ether;
        amounts[2] = 30 ether;

        river.sudoDeal(address(river), 60 ether);
        vm.startPrank(address(river));
        river.approve(address(redeemManager), 60 ether);
        for (uint256 i = 0; i < 3; ++i) {
            recipients[i] = uf._new(20 + i);
            redeemManager.requestRedeem(amounts[i], recipients[i], address(river));
        }
        vm.stopPrank();

        vm.deal(address(this), 30 ether);
        river.sudoReportWithdraw{value: 30 ether}(address(redeemManager), 30 ether);

        _snapshot(3);
    }

    function _snapshot(uint32 _count) internal {
        for (uint32 i = 0; i < _count; ++i) {
            expected.push(redeemManager.getRedeemRequestDetails(i));
        }
    }

    function _queueEnd() internal view returns (uint256) {
        RedeemQueueV2.RedeemRequest storage last = expected[expected.length - 1];
        return last.height + last.amount;
    }

    function _corrupt() internal {
        redeemManager.initializeRedeemManagerV1_2();
    }

    /// @notice Mirror of RedeemManagerV1Recovery._currentQueueHash
    function _queueHash() internal view returns (bytes32 acc) {
        uint256 n = redeemManager.getRedeemRequestCount();
        for (uint32 i = 0; i < n; ++i) {
            RedeemQueueV2.RedeemRequest memory r = redeemManager.getRedeemRequestDetails(i);
            acc = keccak256(abi.encodePacked(acc, r.amount, r.maxRedeemableEth, r.recipient, r.height, r.initiator));
        }
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

        redeemManager.repairRedeemQueue(_payload(), _queueHash());

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
        redeemManager.repairRedeemQueue(_payload(), _queueHash());

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
        redeemManager.repairRedeemQueue(_payload(), _queueHash());

        bytes32 expectedHash = _queueHash();

        vm.expectRevert(RedeemManagerV1Recovery.RedeemQueueAlreadyRepaired.selector);
        redeemManager.repairRedeemQueue(_payload(), expectedHash);
    }

    /// @notice The whole reason pausing is unnecessary: a claim landing between building the payload and
    ///         sending it makes the repair revert instead of silently replaying the pre-claim amount,
    ///         which would let an already-paid request be claimed a second time.
    function testRepairRejectsQueueChangedByAClaimMidWindow() external {
        _seedQueue();
        _corrupt();

        // payload and fingerprint built now
        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        bytes32 staleHash = _queueHash();

        // a claim lands before the repair is sent
        uint32[] memory ids = new uint32[](1);
        uint32[] memory events = new uint32[](1);
        ids[0] = 0;
        events[0] = 0;
        redeemManager.claimRedeemRequests(ids, events);

        bytes32 freshHash = _queueHash();
        assertTrue(staleHash != freshHash, "the claim should have moved the queue");

        vm.expectRevert(
            abi.encodeWithSelector(RedeemManagerV1Recovery.RepairQueueChanged.selector, freshHash, staleHash)
        );
        redeemManager.repairRedeemQueue(payload, staleHash);
    }

    /// @notice Only the proxy admin may repair - recipients come straight from calldata, so an
    ///         unauthorised caller could otherwise redirect every payout while passing all the checks.
    function testRepairRejectsNonAdminCaller() external {
        _seedQueue();
        _corrupt();

        address stranger = uf._new(99);
        bytes32 expectedHash = _queueHash();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        redeemManager.repairRedeemQueue(_payload(), expectedHash);
    }

    function testRepairRejectsWrongLength() external {
        _seedQueue();
        _corrupt();

        RedeemQueueV2.RedeemRequest[] memory short = new RedeemQueueV2.RedeemRequest[](3);
        for (uint256 i = 0; i < 3; ++i) {
            short[i] = expected[i];
        }

        bytes32 expectedHash = _queueHash();

        vm.expectRevert(abi.encodeWithSelector(RedeemManagerV1Recovery.RepairLengthMismatch.selector, 3, 4));
        redeemManager.repairRedeemQueue(short, expectedHash);
    }

    function testRepairRejectsZeroRecipient() external {
        _seedQueue();
        _corrupt();

        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        payload[1].recipient = address(0);

        bytes32 expectedHash = _queueHash();

        vm.expectRevert(abi.encodeWithSelector(RedeemManagerV1Recovery.RepairInvalidRecipient.selector, 1));
        redeemManager.repairRedeemQueue(payload, expectedHash);
    }

    /// @notice A request that starts before its predecessor ends is caught by the geometry checks
    function testRepairRejectsBrokenChain() external {
        _seedQueue();
        _corrupt();

        // Requests 0 and 1 span [0, 30). Dropping request 2 to height 1 makes it overlap them.
        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        payload[2].height = 1 ether;

        uint256 previousEnd = expected[1].height + expected[1].amount;
        bytes32 expectedHash = _queueHash();
        vm.expectRevert(
            abi.encodeWithSelector(
                RedeemManagerV1Recovery.RepairOverlappingRequest.selector, 2, uint256(1 ether), previousEnd
            )
        );
        redeemManager.repairRedeemQueue(payload, expectedHash);
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
        bytes32 expectedHash = _queueHash();
        vm.expectRevert(
            abi.encodeWithSelector(RedeemManagerV1Recovery.RepairDemandMismatch.selector, demand + 1 ether, demand)
        );
        redeemManager.repairRedeemQueue(payload, expectedHash);
    }

    /// @notice A zero initiator would leave the claim path denylist-checking address(0)
    function testRepairRejectsZeroInitiator() external {
        _seedQueue();
        _corrupt();

        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        payload[1].initiator = address(0);

        bytes32 expectedHash = _queueHash();

        vm.expectRevert(abi.encodeWithSelector(RedeemManagerV1Recovery.RepairInvalidInitiator.selector, 1));
        redeemManager.repairRedeemQueue(payload, expectedHash);
    }

    /// @notice A record whose end position does not advance past its predecessor's would be unclaimable
    ///         dead weight in the queue, so a zero size at a legitimate start position is still rejected
    function testRepairRejectsEmptyRequest() external {
        _seedQueue();
        _corrupt();

        // Request 0 spans [0, 10). Parking request 1 at height 10 with no size makes its end position
        // equal to the previous one, which is exactly the degenerate record the check exists for.
        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        payload[1].height = expected[0].height + expected[0].amount;
        payload[1].amount = 0;

        bytes32 expectedHash = _queueHash();

        vm.expectRevert(abi.encodeWithSelector(RedeemManagerV1Recovery.RepairEmptyRequest.selector, 1));
        redeemManager.repairRedeemQueue(payload, expectedHash);
    }

    /// @notice A queue ending below the withdrawal stack is a state `reportWithdraw` can never produce,
    ///         and would under-report what holders are owed
    function testRepairRejectsQueueBelowCoverage() external {
        _seedQueue();
        _corrupt();

        // Shrink every record to 1 ether so the chain stays strictly increasing but the queue ends at
        // 4 ether, far below the 45 ether the withdrawal stack already covers.
        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        for (uint256 i = 0; i < payload.length; ++i) {
            payload[i].height = i * 1 ether;
            payload[i].amount = 1 ether;
        }

        bytes32 expectedHash = _queueHash();

        vm.expectRevert(
            abi.encodeWithSelector(
                RedeemManagerV1Recovery.RepairQueueBelowCoverage.selector, uint256(4 ether), uint256(45 ether)
            )
        );
        redeemManager.repairRedeemQueue(payload, expectedHash);
    }

    /// @notice The events are the only record of what the repair wrote, so they are part of the contract
    function testRepairEmitsAnEventPerRecordAndOneSummary() external {
        _seedQueue();
        _corrupt();

        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        bytes32 expectedHash = _queueHash();
        uint256 demand = redeemManager.getRedeemDemand();
        uint256 queueEnd = _queueEnd();

        for (uint32 i = 0; i < payload.length; ++i) {
            vm.expectEmit(true, true, true, true);
            emit RedeemRequestRepaired(
                i,
                payload[i].amount,
                payload[i].maxRedeemableEth,
                payload[i].recipient,
                payload[i].height,
                payload[i].initiator
            );
        }
        vm.expectEmit(true, true, true, true);
        emit RedeemQueueRepairPerformed(payload.length, queueEnd, demand);

        redeemManager.repairRedeemQueue(payload, expectedHash);
    }

    /// @notice The reason the one-off lives in its own slot: Version must stay at 2 so the repaired
    ///         deployment keeps matching every other one
    function testRepairDoesNotAdvanceVersion() external {
        _seedQueue();
        _corrupt();

        assertEq(uint256(vm.load(address(redeemManager), Version.VERSION_SLOT)), 2, "migration should reach 2");
        assertEq(
            uint256(vm.load(address(redeemManager), RedeemQueueRepaired.REDEEM_QUEUE_REPAIRED_SLOT)),
            0,
            "flag should start clear"
        );

        redeemManager.repairRedeemQueue(_payload(), _queueHash());

        assertEq(uint256(vm.load(address(redeemManager), Version.VERSION_SLOT)), 2, "Version must not advance");
        assertEq(
            uint256(vm.load(address(redeemManager), RedeemQueueRepaired.REDEEM_QUEUE_REPAIRED_SLOT)),
            1,
            "flag should be set"
        );
    }

    /// @notice The flag is written before the payload is validated, so a rejected attempt must not burn
    ///         the single shot the deployment gets
    function testRejectedRepairDoesNotConsumeTheOneShot() external {
        _seedQueue();
        _corrupt();

        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        bytes32 correctHash = _queueHash();

        vm.expectRevert(
            abi.encodeWithSelector(RedeemManagerV1Recovery.RepairQueueChanged.selector, correctHash, bytes32(0))
        );
        redeemManager.repairRedeemQueue(payload, bytes32(0));

        assertEq(
            uint256(vm.load(address(redeemManager), RedeemQueueRepaired.REDEEM_QUEUE_REPAIRED_SLOT)),
            0,
            "the rejected attempt must not have set the flag"
        );

        // The retry with a correct payload still goes through.
        redeemManager.repairRedeemQueue(payload, correctHash);
        assertEq(redeemManager.getRedeemRequestDetails(1).amount, expected[1].amount, "retry should apply");
    }

    /// @notice Access control is checked ahead of the one-off flag, so a stranger cannot burn the shot
    ///         by sending a payload that would fail validation anyway
    function testRepairChecksAuthorizationBeforeTheOneShotFlag() external {
        _seedQueue();
        _corrupt();

        address stranger = uf._new(98);
        RedeemQueueV2.RedeemRequest[] memory payload = _payload();
        bytes32 correctHash = _queueHash();

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        redeemManager.repairRedeemQueue(payload, bytes32(0));

        assertEq(
            uint256(vm.load(address(redeemManager), RedeemQueueRepaired.REDEEM_QUEUE_REPAIRED_SLOT)),
            0,
            "an unauthorized call must not have set the flag"
        );

        redeemManager.repairRedeemQueue(payload, correctHash);
    }

    /// @notice A fully settled request round-trips: its zero amount survives the geometry checks because
    ///         its height is its end position, and it stays unclaimable afterwards
    function testRepairRestoresFullySettledRequest() external {
        _seedQueueWithSettledRequest();
        _corrupt();

        assertTrue(redeemManager.getRedeemRequestDetails(1).amount != expected[1].amount, "not corrupted");

        redeemManager.repairRedeemQueue(_payload(), _queueHash());

        for (uint32 i = 0; i < expected.length; ++i) {
            RedeemQueueV2.RedeemRequest memory got = redeemManager.getRedeemRequestDetails(i);
            assertEq(got.amount, expected[i].amount, "amount");
            assertEq(got.maxRedeemableEth, expected[i].maxRedeemableEth, "maxRedeemableEth");
            assertEq(got.recipient, expected[i].recipient, "recipient");
            assertEq(got.height, expected[i].height, "height");
            assertEq(got.initiator, expected[i].initiator, "initiator");
        }

        uint32[] memory ids = new uint32[](1);
        uint32[] memory events = new uint32[](1);
        vm.expectRevert(abi.encodeWithSelector(IRedeemManagerV1.RedeemRequestAlreadyClaimed.selector, 0));
        redeemManager.claimRedeemRequests(ids, events, false, type(uint16).max);
    }

    /// @notice The staging case: requests made through River carry River as initiator, the migration
    ///         overwrites it with the recipient, and the repair puts it back
    function testRepairRestoresInitiatorDistinctFromRecipient() external {
        address[] memory recipients = _seedQueueViaRiver();

        for (uint32 i = 0; i < 3; ++i) {
            assertEq(expected[i].initiator, address(river), "initiator should be River before the migration");
            assertTrue(expected[i].initiator != recipients[i], "initiator and recipient must differ");
        }

        _corrupt();

        assertEq(
            redeemManager.getRedeemRequestDetails(0).initiator,
            redeemManager.getRedeemRequestDetails(0).recipient,
            "the migration should have clobbered initiator with recipient"
        );

        redeemManager.repairRedeemQueue(_payload(), _queueHash());

        for (uint32 i = 0; i < 3; ++i) {
            RedeemQueueV2.RedeemRequest memory got = redeemManager.getRedeemRequestDetails(i);
            assertEq(got.initiator, address(river), "initiator");
            assertEq(got.recipient, recipients[i], "recipient");
        }
    }

    /// @notice The repair writes the queue and nothing else. RedeemDemand in particular is the witness
    ///         the geometry is checked against, so touching it would destroy the only independent signal.
    function testRepairLeavesTheRestOfTheAccountingUntouched() external {
        _seedQueue();
        _corrupt();

        uint256 demandBefore = redeemManager.getRedeemDemand();
        uint256 bufferedBefore = redeemManager.getBufferedExceedingEth();
        uint256 withdrawalCountBefore = redeemManager.getWithdrawalEventCount();
        WithdrawalStack.WithdrawalEvent memory lastEventBefore =
            redeemManager.getWithdrawalEventDetails(uint32(withdrawalCountBefore - 1));
        uint256 balanceBefore = address(redeemManager).balance;

        redeemManager.repairRedeemQueue(_payload(), _queueHash());

        assertEq(redeemManager.getRedeemDemand(), demandBefore, "redeemDemand");
        assertEq(redeemManager.getBufferedExceedingEth(), bufferedBefore, "bufferedExceedingEth");
        assertEq(redeemManager.getWithdrawalEventCount(), withdrawalCountBefore, "withdrawalEventCount");
        assertEq(address(redeemManager).balance, balanceBefore, "balance");

        WithdrawalStack.WithdrawalEvent memory lastEventAfter =
            redeemManager.getWithdrawalEventDetails(uint32(withdrawalCountBefore - 1));
        assertEq(lastEventAfter.amount, lastEventBefore.amount, "withdrawal event amount");
        assertEq(lastEventAfter.height, lastEventBefore.height, "withdrawal event height");
        assertEq(lastEventAfter.withdrawnEth, lastEventBefore.withdrawnEth, "withdrawal event withdrawnEth");
    }

    /// @notice An empty queue with an empty withdrawal stack satisfies every invariant trivially. Worth
    ///         pinning because it is the one path where the withdrawal stack has no last element to read.
    function testRepairOnEmptyQueueSucceeds() external {
        RedeemQueueV2.RedeemRequest[] memory empty = new RedeemQueueV2.RedeemRequest[](0);

        vm.expectEmit(true, true, true, true);
        emit RedeemQueueRepairPerformed(0, 0, 0);
        redeemManager.repairRedeemQueue(empty, bytes32(0));

        assertEq(redeemManager.getRedeemRequestCount(), 0, "queue should still be empty");
    }
}
