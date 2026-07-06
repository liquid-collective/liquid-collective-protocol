// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/DepositDataBuffer.sol";
import "../src/interfaces/IDepositDataBuffer.sol";
import "../src/libraries/BLS12_381.sol";
import "../src/libraries/LibErrors.sol";

/// @title DepositDataBufferTest
/// @notice Unit coverage for the DepositDataBuffer implementation, ported from the frontrun-mitigation
///         suite and adapted to the liquid-collective `deposits[]/topUps[]` DepositObject shape.
contract DepositDataBufferTest is Test {
    DepositDataBuffer internal buffer;

    address internal admin = makeAddr("admin");
    address internal writer = makeAddr("writer");
    address internal river = makeAddr("river");

    event DepositDataSubmitted(
        bytes32 indexed depositDataBufferId, uint256 nonce, uint256 depositCount, uint256 topUpCount
    );
    event DepositDataProcessed(bytes32 indexed depositDataBufferId);
    event SetWriter(address indexed writer);

    function setUp() public {
        buffer = new DepositDataBuffer(admin, writer, river);
    }

    // -----------------------------------------------------------------------
    // Fixture helpers
    // -----------------------------------------------------------------------

    function _pubkey(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("pubkey", seed)), bytes16(0));
    }

    function _signature(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("sig", seed)), sha256(abi.encode("sig2", seed)), bytes32(0));
    }

    function _deposit(uint256 seed) internal pure returns (IDepositDataBuffer.Deposit memory) {
        BLS12_381.DepositY memory depositY;
        return IDepositDataBuffer.Deposit({
            pubkey: _pubkey(seed),
            signature: _signature(seed),
            amount: 32 ether + seed,
            operatorIdx: seed % 3,
            depositY: depositY
        });
    }

    function _topUp(uint256 seed) internal pure returns (IDepositDataBuffer.TopUp memory) {
        return IDepositDataBuffer.TopUp({pubkey: _pubkey(seed), amount: 1 ether + seed, operatorIdx: seed % 3});
    }

    /// @dev Build a deposits-only batch of `count` initial deposits.
    function _batch(uint256 count) internal pure returns (IDepositDataBuffer.DepositObject memory batch) {
        batch.deposits = new IDepositDataBuffer.Deposit[](count);
        for (uint256 i = 0; i < count; i++) {
            batch.deposits[i] = _deposit(i);
        }
    }

    /// @dev The buffer id folds the batch nonce (the current `lastQueuedIdx`) into the hash.
    function _id(IDepositDataBuffer.DepositObject memory batch, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode(batch, nonce));
    }

    /// @dev Compute the id for the next submission and submit it as the writer.
    function _submit(IDepositDataBuffer.DepositObject memory batch) internal returns (bytes32 id) {
        id = _id(batch, buffer.lastQueuedIdx());
        vm.prank(writer);
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

        vm.prank(writer);
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

        vm.prank(writer);
        buffer.submitDepositData(expectedId, batch);
    }

    function test_IndexIncrements() public {
        assertEq(buffer.lastQueuedIdx(), 0);
        _submit(_batch(1));
        assertEq(buffer.lastQueuedIdx(), 1);
        _submit(_batch(2));
        assertEq(buffer.lastQueuedIdx(), 2);
    }

    function test_RevertWhen_NonWriterSubmits() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        bytes32 id = _id(batch, 0);

        vm.prank(makeAddr("stranger"));
        vm.expectRevert(IDepositDataBuffer.OnlyWriter.selector);
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_EmptyBatch() public {
        IDepositDataBuffer.DepositObject memory batch;
        bytes32 id = _id(batch, 0);
        vm.prank(writer);
        vm.expectRevert(IDepositDataBuffer.EmptyDepositData.selector);
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_IdMismatch() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        // An id computed with the wrong nonce must be rejected.
        bytes32 wrongId = _id(batch, 99);
        bytes32 computed = _id(batch, 0);

        vm.prank(writer);
        vm.expectRevert(
            abi.encodeWithSelector(IDepositDataBuffer.DepositDataBufferIdMismatch.selector, wrongId, computed)
        );
        buffer.submitDepositData(wrongId, batch);
    }

    function test_RevertWhen_InvalidPubkeyLength() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        batch.deposits[0].pubkey = new bytes(47);
        bytes32 id = _id(batch, 0);
        vm.prank(writer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidPubkeyLength.selector, 0, 47));
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_InvalidSignatureLength() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        batch.deposits[0].signature = new bytes(95);
        bytes32 id = _id(batch, 0);
        vm.prank(writer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidSignatureLength.selector, 0, 95));
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_ZeroDepositAmount() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        batch.deposits[0].amount = 0;
        bytes32 id = _id(batch, 0);
        vm.prank(writer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidDepositAmount.selector, 0, 0));
        buffer.submitDepositData(id, batch);
    }

    function test_RevertWhen_InvalidTopUpPubkeyLength() public {
        IDepositDataBuffer.DepositObject memory batch;
        batch.topUps = new IDepositDataBuffer.TopUp[](1);
        batch.topUps[0] = _topUp(1);
        batch.topUps[0].pubkey = new bytes(49);
        bytes32 id = _id(batch, 0);
        vm.prank(writer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidTopUpPubkeyLength.selector, 0, 49));
        buffer.submitDepositData(id, batch);
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
    // markDepositDataProcessed (River-only)
    // -----------------------------------------------------------------------

    function test_RiverCanMarkProcessed() public {
        bytes32 id = _submit(_batch(2));
        assertFalse(buffer.isDepositDataProcessed(id));

        vm.expectEmit(true, false, false, false);
        emit DepositDataProcessed(id);

        vm.prank(river);
        buffer.markDepositDataProcessed(id);

        assertTrue(buffer.isDepositDataProcessed(id));
    }

    function test_MarkProcessedLeavesDataUntouched() public {
        IDepositDataBuffer.DepositObject memory batch = _batch(2);
        bytes32 id = _submit(batch);

        vm.prank(river);
        buffer.markDepositDataProcessed(id);

        (IDepositDataBuffer.DepositObject memory stored,) = buffer.getDepositData(id);
        assertEq(stored.deposits.length, 2);
        assertEq(stored.deposits[0].pubkey, batch.deposits[0].pubkey);
    }

    function test_RevertWhen_NonRiverMarksProcessed() public {
        bytes32 id = _submit(_batch(1));
        vm.prank(makeAddr("notRiver"));
        vm.expectRevert(IDepositDataBuffer.OnlyRiver.selector);
        buffer.markDepositDataProcessed(id);
        assertFalse(buffer.isDepositDataProcessed(id));
    }

    function test_RevertWhen_MarkProcessedUnknownBatch() public {
        vm.prank(river);
        vm.expectRevert(
            abi.encodeWithSelector(IDepositDataBuffer.DepositDataBufferIdNotFound.selector, bytes32(uint256(0xdead)))
        );
        buffer.markDepositDataProcessed(bytes32(uint256(0xdead)));
    }

    function test_RevertWhen_MarkProcessedTwice() public {
        bytes32 id = _submit(_batch(2));
        vm.prank(river);
        buffer.markDepositDataProcessed(id);

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.DepositDataAlreadyProcessed.selector, id));
        buffer.markDepositDataProcessed(id);
    }

    function test_MarkProcessedOnlyAffectsTargetBatch() public {
        bytes32 id1 = _submit(_batch(2));
        bytes32 id2 = _submit(_batch(3));

        vm.prank(river);
        buffer.markDepositDataProcessed(id1);

        assertTrue(buffer.isDepositDataProcessed(id1));
        assertFalse(buffer.isDepositDataProcessed(id2));
    }

    // -----------------------------------------------------------------------
    // Access control / views
    // -----------------------------------------------------------------------

    function test_ConstructorSetsRoles() public {
        assertEq(buffer.getAdmin(), admin);
        assertEq(buffer.getWriter(), writer);
        assertEq(buffer.RIVER(), river);
        assertEq(buffer.lastQueuedIdx(), 0);
    }

    function test_RevertWhen_ConstructorAdminIsZero() public {
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        new DepositDataBuffer(address(0), writer, river);
    }

    function test_RevertWhen_ConstructorWriterIsZero() public {
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        new DepositDataBuffer(admin, address(0), river);
    }

    function test_RevertWhen_ConstructorRiverIsZero() public {
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        new DepositDataBuffer(admin, writer, address(0));
    }

    function test_AdminCanRotateWriter() public {
        address newWriter = makeAddr("newWriter");

        vm.expectEmit(true, false, false, false);
        emit SetWriter(newWriter);
        vm.prank(admin);
        buffer.setWriter(newWriter);
        assertEq(buffer.getWriter(), newWriter);

        // Old writer can no longer submit; the new writer can.
        IDepositDataBuffer.DepositObject memory batch = _batch(1);
        bytes32 id = _id(batch, 0);
        vm.prank(writer);
        vm.expectRevert(IDepositDataBuffer.OnlyWriter.selector);
        buffer.submitDepositData(id, batch);

        vm.prank(newWriter);
        buffer.submitDepositData(id, batch);
        assertEq(buffer.lastQueuedIdx(), 1);
    }

    function test_RevertWhen_NonAdminRotatesWriter() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(IDepositDataBuffer.OnlyAdmin.selector);
        buffer.setWriter(makeAddr("newWriter"));
    }

    function test_RevertWhen_SetWriterZero() public {
        vm.prank(admin);
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        buffer.setWriter(address(0));
    }
}
