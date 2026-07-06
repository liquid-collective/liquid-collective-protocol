// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/DepositDataBuffer.sol";
import "../../src/interfaces/IDepositDataBuffer.sol";
import "../../src/libraries/BLS12_381.sol";

/// @title DepositDataBufferFuzzTest
/// @notice Fuzz coverage for the DepositDataBuffer, ported from the frontrun-mitigation suite and
///         adapted to the `deposits[]/topUps[]` DepositObject shape.
contract DepositDataBufferFuzzTest is Test {
    DepositDataBuffer internal buffer;

    address internal writer = makeAddr("writer");

    function setUp() public {
        buffer = new DepositDataBuffer(makeAddr("admin"), writer, makeAddr("river"));
    }

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
            amount: 32 ether,
            operatorIdx: seed % 5,
            depositY: depositY
        });
    }

    function _batch(uint256 count, uint256 seedBase)
        internal
        pure
        returns (IDepositDataBuffer.DepositObject memory batch)
    {
        batch.deposits = new IDepositDataBuffer.Deposit[](count);
        for (uint256 i = 0; i < count; i++) {
            batch.deposits[i] = _deposit(seedBase + i);
        }
    }

    function _submit(IDepositDataBuffer.DepositObject memory batch) internal returns (bytes32 id) {
        id = keccak256(abi.encode(batch, buffer.lastQueuedIdx()));
        vm.prank(writer);
        buffer.submitDepositData(id, batch);
    }

    // -----------------------------------------------------------------------
    // Varying batch sizes — nonce equals index
    // -----------------------------------------------------------------------

    function testFuzz_submitVaryingBatchSize(uint8 size, uint256 seed) public {
        // Cap seed so `seedBase + i` cannot overflow in the fixture builder.
        seed = bound(seed, 0, type(uint256).max - 20);
        uint256 count = bound(uint256(size), 1, 10);
        IDepositDataBuffer.DepositObject memory batch = _batch(count, seed);

        bytes32 id = _submit(batch);

        (IDepositDataBuffer.DepositObject memory stored, uint256 nonce) = buffer.getDepositData(id);
        assertEq(stored.deposits.length, count);
        assertEq(nonce, 0, "first submission uses batch nonce 0");
        assertEq(buffer.lastQueuedIdx(), 1);
    }

    // -----------------------------------------------------------------------
    // The stored (batch, nonce) always hashes back to its id (verifier tamper-check property)
    // -----------------------------------------------------------------------

    function testFuzz_storedBatchHashesToId(uint8 size, uint256 seed) public {
        seed = bound(seed, 0, type(uint256).max - 2000);
        uint256 count = bound(uint256(size), 1, 10);
        // Bump the nonce a fuzzed number of times so the stored nonce is non-trivial.
        uint256 bumps = bound(seed, 0, 4);
        for (uint256 i = 0; i < bumps; i++) {
            _submit(_batch(1, 1000 + i));
        }

        IDepositDataBuffer.DepositObject memory batch = _batch(count, seed);
        bytes32 id = _submit(batch);

        (IDepositDataBuffer.DepositObject memory stored, uint256 nonce) = buffer.getDepositData(id);
        assertEq(nonce, bumps);
        assertEq(keccak256(abi.encode(stored, nonce)), id, "stored batch+nonce must reproduce the id");
    }

    // -----------------------------------------------------------------------
    // Identical data is distinguishable via the batch nonce
    // -----------------------------------------------------------------------

    function testFuzz_identicalDataYieldsDistinctIds(uint256 seed) public {
        seed = bound(seed, 0, type(uint256).max - 20);
        uint256 count = bound(seed, 1, 5);
        IDepositDataBuffer.DepositObject memory batch = _batch(count, seed);

        bytes32 id0 = keccak256(abi.encode(batch, uint256(0)));
        bytes32 id1 = keccak256(abi.encode(batch, uint256(1)));
        assertTrue(id0 != id1);

        assertEq(_submit(batch), id0);
        assertEq(_submit(batch), id1); // byte-identical data, distinct id

        (, uint256 n0) = buffer.getDepositData(id0);
        (, uint256 n1) = buffer.getDepositData(id1);
        assertEq(n0, 0);
        assertEq(n1, 1);
        assertEq(buffer.lastQueuedIdx(), 2);
    }

    // -----------------------------------------------------------------------
    // Field validation
    // -----------------------------------------------------------------------

    function testFuzz_invalidPubkeyLength(uint8 len) public {
        vm.assume(len != 48);
        IDepositDataBuffer.DepositObject memory batch = _batch(1, 0);
        batch.deposits[0].pubkey = new bytes(uint256(len));

        vm.prank(writer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidPubkeyLength.selector, 0, uint256(len)));
        buffer.submitDepositData(bytes32(0), batch);
    }

    function testFuzz_invalidSignatureLength(uint8 len) public {
        vm.assume(len != 96);
        IDepositDataBuffer.DepositObject memory batch = _batch(1, 0);
        batch.deposits[0].signature = new bytes(uint256(len));

        vm.prank(writer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidSignatureLength.selector, 0, uint256(len)));
        buffer.submitDepositData(bytes32(0), batch);
    }

    function testFuzz_invalidTopUpPubkeyLength(uint8 len) public {
        vm.assume(len != 48);
        IDepositDataBuffer.DepositObject memory batch;
        batch.topUps = new IDepositDataBuffer.TopUp[](1);
        batch.topUps[0] = IDepositDataBuffer.TopUp({pubkey: new bytes(uint256(len)), amount: 1 ether, operatorIdx: 0});

        vm.prank(writer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidTopUpPubkeyLength.selector, 0, uint256(len)));
        buffer.submitDepositData(bytes32(0), batch);
    }

    function testFuzz_zeroDepositAmountReverts(uint256 seed) public {
        IDepositDataBuffer.DepositObject memory batch = _batch(1, seed);
        batch.deposits[0].amount = 0;

        vm.prank(writer);
        vm.expectRevert(abi.encodeWithSelector(IDepositDataBuffer.InvalidDepositAmount.selector, 0, 0));
        buffer.submitDepositData(bytes32(0), batch);
    }
}
