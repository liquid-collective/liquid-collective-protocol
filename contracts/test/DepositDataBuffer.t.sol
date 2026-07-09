// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/DepositDataBuffer.sol";
import "../src/interfaces/IDepositDataBuffer.sol";
import "../src/libraries/LibErrors.sol";
import "./shared/DepositDataBufferFixtures.sol";

/// @title DepositDataBufferTest
/// @notice Unit coverage for the DepositDataBuffer implementation, ported from the frontrun-mitigation
///         suite and adapted to the liquid-collective `deposits[]/topUps[]` DepositObject shape.
contract DepositDataBufferTest is Test, DepositDataBufferFixtures {
    DepositDataBuffer internal buffer;

    address internal admin = makeAddr("admin");
    address internal producer = makeAddr("producer");
    address internal processor = makeAddr("processor");

    event DepositDataSubmitted(
        bytes32 indexed depositDataBufferId, uint256 nonce, uint256 depositCount, uint256 topUpCount
    );
    event DepositDataProcessed(bytes32 indexed depositDataBufferId);
    event SetProducer(address indexed producer);
    event SetPendingAdmin(address indexed pendingAdmin);
    event SetAdmin(address indexed admin);

    function setUp() public {
        buffer = new DepositDataBuffer(admin, producer, processor);
    }

    // -----------------------------------------------------------------------
    // Test-local helpers (fixtures are inherited from DepositDataBufferFixtures)
    // -----------------------------------------------------------------------

    /// @dev The buffer id folds the batch nonce (the current `lastQueuedIdx`) into the hash.
    function _id(IDepositDataBuffer.DepositObject memory batch, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode(batch, nonce));
    }

    /// @dev Compute the id for the next submission and submit it as the producer.
    function _submit(IDepositDataBuffer.DepositObject memory batch) internal returns (bytes32 id) {
        id = _id(batch, buffer.lastQueuedIdx());
        vm.prank(producer);
        buffer.submitDepositData(id, batch);
    }

    // -----------------------------------------------------------------------
    // submitDepositData
    // -----------------------------------------------------------------------

    function test_SubmitSingle() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        bytes32 expectedId = _id(batch, 0);

        vm.expectEmit(true, false, false, true);
        emit DepositDataSubmitted(expectedId, 0, 1, 0);

        vm.prank(producer);
        buffer.submitDepositData(expectedId, batch);

        assertEq(buffer.lastQueuedIdx(), 1);
    }

    function test_SubmitMixedDepositsAndTopUps() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(2);
        batch.topUps = new IDepositDataBuffer.TopUp[](1);
        batch.topUps[0] = _topUp(50);

        bytes32 expectedId = _id(batch, 0);
        vm.expectEmit(true, false, false, true);
        emit DepositDataSubmitted(expectedId, 0, 2, 1);

        vm.prank(producer);
        buffer.submitDepositData(expectedId, batch);
    }

    function test_IndexIncrements() public {
        assertEq(buffer.lastQueuedIdx(), 0);
        _submit(_batch(1));
        assertEq(buffer.lastQueuedIdx(), 1);
        _submit(_batch(2));
        assertEq(buffer.lastQueuedIdx(), 2);
    }

    function test_RevertWhen_NonProducerSubmits() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        bytes32 id = _id(batch, 0);

        vm.prank(makeAddr("stranger"));
        vm.expectRevert(IDepositDataBuffer.OnlyProducer.selector);
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_EmptyBatch() public {
        IDepositDataBuffer.DepositObject memory batch;
        bytes32 id = _id(batch, 0);
        vm.prank(producer);
        vm.expectRevert(IDepositDataBuffer.EmptyDepositData.selector);
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_IdMismatch() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        // An id computed with the wrong nonce must be rejected.
        bytes32 wrongId = _id(batch, 99);
        bytes32 computed = _id(batch, 0);

        vm.prank(producer);
        vm.expectRevert(
            abi.encodeWithSelector(IDepositDataBuffer.DepositDataBufferIdMismatch.selector, wrongId, computed)
        );
        buffer.submitDepositData(wrongId, batch);
    }

    /// @dev The `DepositDataBufferIdAlreadyExists` guard is unreachable through the normal API — the
    ///      monotonic nonce folded into the id makes every submission unique. Force the `_exists` flag
    ///      via storage to prove the defensive guard still reverts on a (hypothetical) id collision.
    function test_RevertWhen_IdAlreadyExists() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        bytes32 id = _id(batch, 0);

        // Storage layout: _admin(0), _pendingAdmin(1), _producer(2), lastQueuedIdx(3), _batches(4),
        // _nonce(5), _exists(6). (_processor is immutable, so it lives in code, not storage.)
        bytes32 existsSlot = keccak256(abi.encode(id, uint256(6)));
        vm.store(address(buffer), existsSlot, bytes32(uint256(1)));
        assertTrue(buffer.isDepositDataProcessed(id) == false); // sanity: _processed untouched

        vm.prank(producer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.DepositDataBufferIdAlreadyExists.selector, id));
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_InvalidPubkeyLength() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        batch.deposits[0].pubkey = new bytes(47);
        bytes32 id = _id(batch, 0);
        vm.prank(producer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidPubkeyLength.selector, 0, 47));
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_InvalidSignatureLength() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        batch.deposits[0].signature = new bytes(95);
        bytes32 id = _id(batch, 0);
        vm.prank(producer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidSignatureLength.selector, 0, 95));
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_ZeroDepositAmount() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        batch.deposits[0].amount = 0;
        bytes32 id = _id(batch, 0);
        vm.prank(producer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidDepositAmount.selector, 0, 0));
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_DepositAmountNotGweiAligned() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        uint256 misaligned = 32 ether + 1 wei; // non-zero but not a multiple of 1 gwei
        batch.deposits[0].amount = misaligned;
        bytes32 id = _id(batch, 0);
        vm.prank(producer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidDepositAmount.selector, 0, misaligned));
        buffer.submitDepositData(id, batch);
    }

    /// @dev The validation index in `InvalidDepositAmount` must point at the offending entry.
    function test_RevertWhen_SecondDepositAmountNotGweiAligned() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(2);
        uint256 misaligned = 32 ether + 3 wei;
        batch.deposits[1].amount = misaligned;
        bytes32 id = _id(batch, 0);
        vm.prank(producer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidDepositAmount.selector, 1, misaligned));
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_InvalidTopUpPubkeyLength() public {
        IDepositDataBuffer.DepositObject memory batch;
        batch.topUps = new IDepositDataBuffer.TopUp[](1);
        batch.topUps[0] = _topUp(1);
        batch.topUps[0].pubkey = new bytes(49);
        bytes32 id = _id(batch, 0);
        vm.prank(producer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidTopUpPubkeyLength.selector, 0, 49));
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_ZeroTopUpAmount() public {
        IDepositDataBuffer.DepositObject memory batch;
        batch.topUps = new IDepositDataBuffer.TopUp[](1);
        batch.topUps[0] = _topUp(1);
        batch.topUps[0].amount = 0;
        bytes32 id = _id(batch, 0);
        vm.prank(producer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidDepositAmount.selector, 0, 0));
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_TopUpAmountNotGweiAligned() public {
        IDepositDataBuffer.DepositObject memory batch;
        batch.topUps = new IDepositDataBuffer.TopUp[](1);
        batch.topUps[0] = _topUp(1);
        uint256 misaligned = 1 ether + 7 wei;
        batch.topUps[0].amount = misaligned;
        bytes32 id = _id(batch, 0);
        vm.prank(producer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidDepositAmount.selector, 0, misaligned));
        buffer.submitDepositData(id, batch);
    }

    /// @dev A batch of only top-ups (no initial deposits) is valid.
    function test_SubmitTopUpsOnly() public {
        IDepositDataBuffer.DepositObject memory batch;
        batch.topUps = new IDepositDataBuffer.TopUp[](2);
        batch.topUps[0] = _topUp(10);
        batch.topUps[1] = _topUp(11);

        bytes32 expectedId = _id(batch, 0);
        vm.expectEmit(true, false, false, true);
        emit DepositDataSubmitted(expectedId, 0, 0, 2);

        bytes32 id = _submit(batch);
        assertEq(id, expectedId);

        (IDepositDataBuffer.DepositObject memory stored, uint256 nonce) = buffer.getDepositData(id);
        assertEq(nonce, 0);
        assertEq(stored.deposits.length, 0);
        assertEq(stored.topUps.length, 2);
        assertEq(stored.topUps[0].pubkey, batch.topUps[0].pubkey);
        assertEq(stored.topUps[1].amount, batch.topUps[1].amount);
        assertEq(stored.topUps[1].operatorIdx, batch.topUps[1].operatorIdx);
    }

    // -----------------------------------------------------------------------
    // getDepositData
    // -----------------------------------------------------------------------

    function test_GetDepositDataReturnsBatchAndNonce() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(2);
        _submit(_batch(1)); // bump the nonce so the retrieved nonce is non-trivial
        bytes32 id = _submit(batch);

        (IDepositDataBuffer.DepositObject memory stored, uint256 nonce) = buffer.getDepositData(id);
        assertEq(nonce, 1, "stored nonce must equal lastQueuedIdx at submit time");
        assertEq(stored.deposits.length, 2);
        for (uint256 i = 0; i < 2; i++) {
            assertEq(stored.deposits[i].pubkey, batch.deposits[i].pubkey);
            assertEq(stored.deposits[i].signature, batch.deposits[i].signature);
            assertEq(stored.deposits[i].amount, batch.deposits[i].amount);
            assertEq(stored.deposits[i].operatorIdx, batch.deposits[i].operatorIdx);
        }
        // The stored (batch, nonce) must hash back to the id — the verifier's tamper-check property.
        assertEq(_id(stored, nonce), id, "stored batch+nonce must hash to its id");
    }

    function test_RevertWhen_GetUnknownId() public {
        vm.expectRevert(
            abi.encodeWithSelector(IDepositDataBuffer.DepositDataBufferIdNotFound.selector, bytes32(uint256(0xdead)))
        );
        buffer.getDepositData(bytes32(uint256(0xdead)));
    }

    /// @dev `isDepositDataProcessed` returns false for an unknown id (view, no revert).
    function test_IsDepositDataProcessedUnknownReturnsFalse() public {
        assertFalse(buffer.isDepositDataProcessed(bytes32(uint256(0xbeef))));
    }

    /// @dev A reverted submission must not advance `lastQueuedIdx` or store anything.
    function test_LastQueuedIdxUnchangedOnRevertedSubmit() public {
        _submit(_batch(1));
        assertEq(buffer.lastQueuedIdx(), 1);

        // A submission with a mismatched id reverts and must leave state untouched.
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        bytes32 wrongId = _id(batch, 999);
        vm.prank(producer);
        vm.expectRevert();
        buffer.submitDepositData(wrongId, batch);

        assertEq(buffer.lastQueuedIdx(), 1, "reverted submit must not bump the index");
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.DepositDataBufferIdNotFound.selector, wrongId));
        buffer.getDepositData(wrongId);
    }

    // -----------------------------------------------------------------------
    // Nonce folding — identical data is distinguishable
    // -----------------------------------------------------------------------

    function test_IdenticalDataSubmitsTwiceWithDistinctIds() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(2);

        bytes32 id0 = _id(batch, 0);
        bytes32 id1 = _id(batch, 1);
        assertTrue(id0 != id1, "identical data must receive distinct ids per submission");

        bytes32 firstId = _submit(batch);
        bytes32 secondId = _submit(batch);

        assertEq(firstId, id0);
        assertEq(secondId, id1);
        assertEq(buffer.lastQueuedIdx(), 2);

        (, uint256 n0) = buffer.getDepositData(id0);
        (, uint256 n1) = buffer.getDepositData(id1);
        assertEq(n0, 0);
        assertEq(n1, 1);
    }

    // -----------------------------------------------------------------------
    // markDepositDataProcessed (processor-only)
    // -----------------------------------------------------------------------

    function test_ProcessorCanMarkProcessed() public {
        bytes32 id = _submit(_batch(2));
        assertFalse(buffer.isDepositDataProcessed(id));

        vm.expectEmit(true, false, false, false);
        emit DepositDataProcessed(id);

        vm.prank(processor);
        buffer.markDepositDataProcessed(id);

        assertTrue(buffer.isDepositDataProcessed(id));
    }

    function test_MarkProcessedLeavesDataUntouched() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(2);
        bytes32 id = _submit(batch);

        vm.prank(processor);
        buffer.markDepositDataProcessed(id);

        (IDepositDataBuffer.DepositObject memory stored,) = buffer.getDepositData(id);
        assertEq(stored.deposits.length, 2);
        assertEq(stored.deposits[0].pubkey, batch.deposits[0].pubkey);
    }

    function test_RevertWhen_NonProcessorMarksProcessed() public {
        bytes32 id = _submit(_batch(1));
        vm.prank(makeAddr("notProcessor"));
        vm.expectRevert(IDepositDataBuffer.OnlyProcessor.selector);
        buffer.markDepositDataProcessed(id);
        assertFalse(buffer.isDepositDataProcessed(id));
    }

    function test_RevertWhen_MarkProcessedUnknownBatch() public {
        vm.prank(processor);
        vm.expectRevert(
            abi.encodeWithSelector(IDepositDataBuffer.DepositDataBufferIdNotFound.selector, bytes32(uint256(0xdead)))
        );
        buffer.markDepositDataProcessed(bytes32(uint256(0xdead)));
    }

    function test_RevertWhen_MarkProcessedTwice() public {
        bytes32 id = _submit(_batch(2));
        vm.prank(processor);
        buffer.markDepositDataProcessed(id);

        vm.prank(processor);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.DepositDataAlreadyProcessed.selector, id));
        buffer.markDepositDataProcessed(id);
    }

    function test_MarkProcessedOnlyAffectsTargetBatch() public {
        bytes32 id1 = _submit(_batch(2));
        bytes32 id2 = _submit(_batch(3));

        vm.prank(processor);
        buffer.markDepositDataProcessed(id1);

        assertTrue(buffer.isDepositDataProcessed(id1));
        assertFalse(buffer.isDepositDataProcessed(id2));
    }

    // -----------------------------------------------------------------------
    // Access control / views
    // -----------------------------------------------------------------------

    function test_ConstructorSetsRoles() public {
        assertEq(buffer.getAdmin(), admin);
        assertEq(buffer.getPendingAdmin(), address(0));
        assertEq(buffer.getProducer(), producer);
        assertEq(buffer.getProcessor(), processor);
        assertEq(buffer.lastQueuedIdx(), 0);
    }

    function test_RevertWhen_ConstructorAdminIsZero() public {
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        new DepositDataBuffer(address(0), producer, processor);
    }

    function test_RevertWhen_ConstructorProducerIsZero() public {
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        new DepositDataBuffer(admin, address(0), processor);
    }

    function test_RevertWhen_ConstructorProcessorIsZero() public {
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        new DepositDataBuffer(admin, producer, address(0));
    }

    function test_AdminCanRotateProducer() public {
        address newProducer = makeAddr("newProducer");

        vm.expectEmit(true, false, false, false);
        emit SetProducer(newProducer);
        vm.prank(admin);
        buffer.setProducer(newProducer);
        assertEq(buffer.getProducer(), newProducer);

        // Old producer can no longer submit; the new producer can.
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        bytes32 id = _id(batch, 0);
        vm.prank(producer);
        vm.expectRevert(IDepositDataBuffer.OnlyProducer.selector);
        buffer.submitDepositData(id, batch);

        vm.prank(newProducer);
        buffer.submitDepositData(id, batch);
        assertEq(buffer.lastQueuedIdx(), 1);
    }

    function test_RevertWhen_NonAdminRotatesProducer() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(IDepositDataBuffer.OnlyAdmin.selector);
        buffer.setProducer(makeAddr("newProducer"));
    }

    function test_RevertWhen_SetProducerZero() public {
        vm.prank(admin);
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        buffer.setProducer(address(0));
    }

    // -----------------------------------------------------------------------
    // Two-step admin transfer (propose / accept)
    // -----------------------------------------------------------------------

    function test_AdminTransfer_ProposeThenAccept() public {
        address newAdmin = makeAddr("newAdmin");

        vm.expectEmit(true, false, false, false);
        emit SetPendingAdmin(newAdmin);
        vm.prank(admin);
        buffer.proposeAdmin(newAdmin);

        // Proposing does not transfer power yet: admin unchanged, pending set.
        assertEq(buffer.getAdmin(), admin);
        assertEq(buffer.getPendingAdmin(), newAdmin);

        vm.expectEmit(true, false, false, false);
        emit SetAdmin(newAdmin);
        vm.prank(newAdmin);
        buffer.acceptAdmin();

        // Transfer complete: admin promoted, pending cleared.
        assertEq(buffer.getAdmin(), newAdmin);
        assertEq(buffer.getPendingAdmin(), address(0));
    }

    function test_AdminTransfer_NewAdminCanActOldCannot() public {
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        buffer.proposeAdmin(newAdmin);
        vm.prank(newAdmin);
        buffer.acceptAdmin();

        // Old admin has lost admin power.
        vm.prank(admin);
        vm.expectRevert(IDepositDataBuffer.OnlyAdmin.selector);
        buffer.setProducer(makeAddr("x"));

        // New admin can rotate the producer.
        address newProducer = makeAddr("newProducer");
        vm.prank(newAdmin);
        buffer.setProducer(newProducer);
        assertEq(buffer.getProducer(), newProducer);
    }

    function test_RevertWhen_NonAdminProposes() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(IDepositDataBuffer.OnlyAdmin.selector);
        buffer.proposeAdmin(makeAddr("newAdmin"));
    }

    function test_RevertWhen_ProposeAdminZero() public {
        vm.prank(admin);
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        buffer.proposeAdmin(address(0));
    }

    function test_RevertWhen_NonPendingAdminAccepts() public {
        vm.prank(admin);
        buffer.proposeAdmin(makeAddr("newAdmin"));

        // Neither a stranger nor the current admin may accept — only the pending admin.
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(IDepositDataBuffer.OnlyPendingAdmin.selector);
        buffer.acceptAdmin();

        vm.prank(admin);
        vm.expectRevert(IDepositDataBuffer.OnlyPendingAdmin.selector);
        buffer.acceptAdmin();
    }

    function test_RevertWhen_AcceptWithNoPending() public {
        // No transfer in progress: pending admin is zero, so nobody can accept.
        vm.prank(makeAddr("anyone"));
        vm.expectRevert(IDepositDataBuffer.OnlyPendingAdmin.selector);
        buffer.acceptAdmin();
    }

    function test_AdminTransfer_ProposeCanBeOverwritten() public {
        address first = makeAddr("first");
        address second = makeAddr("second");

        vm.prank(admin);
        buffer.proposeAdmin(first);
        vm.prank(admin);
        buffer.proposeAdmin(second);
        assertEq(buffer.getPendingAdmin(), second);

        // The superseded proposal can no longer accept.
        vm.prank(first);
        vm.expectRevert(IDepositDataBuffer.OnlyPendingAdmin.selector);
        buffer.acceptAdmin();

        vm.prank(second);
        buffer.acceptAdmin();
        assertEq(buffer.getAdmin(), second);
    }
}
