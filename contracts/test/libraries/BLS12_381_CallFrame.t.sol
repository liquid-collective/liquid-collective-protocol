// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BLS12_381} from "../../src/libraries/BLS12_381.sol";
import {BLSSigner} from "../utils/BLSSigner.sol";

/**
 * @notice Pins the memory-frame precondition of `BLS12_381.hashToG2`, and the fact that batch
 *         deposit verification satisfies it.
 * @dev `hashToG2` builds its `expand_message_xmd` input (RFC 9380 5.3.1) in scratch memory past
 *      the free pointer, takes the leading 64-byte `Z_pad` to be implicitly zero without zeroing
 *      it, and dirties ~0x300 bytes past the free pointer without bumping it. A second call at the
 *      *same* free pointer therefore hashes the first call's leftovers and returns a different
 *      curve point. `testHashToG2IsNotIdempotentAtTheSameFreePointer` is the negative control that
 *      keeps that hazard honest; `testBatchOfDepositsVerifiesInOneFrame` is the positive result
 *      that matters for production: `verifyDepositMessage` is an `external` library function, so
 *      every invocation is a `STATICCALL`/`DELEGATECALL` into a fresh memory frame and an N-deposit
 *      batch verified in a single transaction cannot poison itself.
 */
contract BLS12_381CallFrameHarness {
    /// @notice Verifies `deposits` in a single call frame, exactly as `_verifyBLSSignatures` does.
    function verifyBatch(
        BLSSigner.SignedDeposit[] memory deposits,
        uint256 amount,
        bytes32 withdrawalCredentials,
        bytes32 depositDomain
    ) external view {
        for (uint256 i = 0; i < deposits.length; i++) {
            BLS12_381.verifyDepositMessage(
                deposits[i].pubkey,
                deposits[i].signature,
                amount,
                deposits[i].depositY,
                withdrawalCredentials,
                depositDomain
            );
        }
    }

    /// @notice Hashes `message` twice, forcing the second `hashToG2` to reuse the first one's
    ///         scratch region by restoring the free memory pointer in between.
    function hashToG2TwiceAtSameFreePointer(bytes32 message)
        external
        view
        returns (bytes32 firstHash, bytes32 secondHash)
    {
        uint256 freePointer;
        assembly {
            freePointer := mload(0x40)
        }

        BLS12_381.G2Point memory first = BLS12_381.hashToG2(message);
        firstHash = keccak256(abi.encode(first));

        assembly {
            mstore(0x40, freePointer)
        }

        BLS12_381.G2Point memory second = BLS12_381.hashToG2(message);
        secondHash = keccak256(abi.encode(second));
    }

    /// @notice `hashToG2` once per call frame, for the clean-memory reference value.
    function hashToG2Once(bytes32 message) external view returns (bytes32) {
        return keccak256(abi.encode(BLS12_381.hashToG2(message)));
    }
}

contract BLS12_381CallFrameTest is Test {
    BLSSigner internal signer;
    BLS12_381CallFrameHarness internal harness;

    bytes32 internal constant WITHDRAWAL_CREDENTIALS =
        0x02000000000000000000000000000000000000000000000000000000CAFEBABE;

    bytes32 internal depositDomain;

    function setUp() public {
        signer = new BLSSigner();
        harness = new BLS12_381CallFrameHarness();
        depositDomain = BLS12_381.computeDepositDomain(bytes4(0));
    }

    /// @dev The hazard is real: reusing the scratch region silently changes the curve point.
    function testHashToG2IsNotIdempotentAtTheSameFreePointer() public {
        bytes32 message = keccak256("BLS12_381.hashToG2 scratch reuse");
        (bytes32 firstHash, bytes32 secondHash) = harness.hashToG2TwiceAtSameFreePointer(message);

        assertEq(firstHash, harness.hashToG2Once(message), "first call must match a clean frame");
        assertTrue(secondHash != firstHash, "scratch reuse must be observable, or this control is dead");
    }

    /// @dev The production shape: one call frame, many deposits, every signature must verify.
    ///      `verifyDepositMessage` being an `external` library function gives each iteration its
    ///      own memory frame, so the hazard above cannot reach a batch.
    function testBatchOfDepositsVerifiesInOneFrame() public view {
        uint256[] memory seeds = new uint256[](8);
        for (uint256 i = 0; i < seeds.length; ++i) {
            seeds[i] = 7_000 + i;
        }

        BLSSigner.SignedDeposit[] memory batch =
            signer.signDepositsFromSeeds(seeds, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);

        harness.verifyBatch(batch, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
    }

    /// @dev A corrupted entry anywhere in the batch must still be caught, so the batch path is not
    ///      passing by accident.
    function testBatchRejectsATamperedEntry() public {
        uint256[] memory seeds = new uint256[](4);
        for (uint256 i = 0; i < seeds.length; ++i) {
            seeds[i] = 8_000 + i;
        }

        BLSSigner.SignedDeposit[] memory batch =
            signer.signDepositsFromSeeds(seeds, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
        // Give entry 2 entry 3's signature: still a valid curve point, wrong message.
        batch[2].signature = batch[3].signature;
        batch[2].depositY.signatureY = batch[3].depositY.signatureY;

        vm.expectRevert(BLS12_381.InvalidSignature.selector);
        harness.verifyBatch(batch, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
    }

    /// @dev Marginal gas of one extra deposit inside a batch, reported for the record.
    function testMarginalGasPerDepositInABatch() public {
        uint256 gasThree = _measureBatch(3);
        uint256 gasFour = _measureBatch(4);
        uint256 gasFive = _measureBatch(5);

        emit log_named_uint("batch(3) total gas", gasThree);
        emit log_named_uint("batch(4) total gas", gasFour);
        emit log_named_uint("batch(5) total gas", gasFive);
        emit log_named_uint("marginal gas per deposit (4-3)", gasFour - gasThree);
        emit log_named_uint("marginal gas per deposit (5-4)", gasFive - gasFour);

        // The per-deposit cost is dominated by the BLS precompiles, not by the library call
        // boundary; this only guards against an order-of-magnitude regression.
        assertLt(gasFive - gasFour, 600_000, "per-deposit verification cost regressed");
    }

    function _measureBatch(uint256 count) internal view returns (uint256) {
        uint256[] memory seeds = new uint256[](count);
        for (uint256 i = 0; i < count; ++i) {
            seeds[i] = 9_000 + i;
        }
        BLSSigner.SignedDeposit[] memory batch =
            signer.signDepositsFromSeeds(seeds, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);

        uint256 before = gasleft();
        harness.verifyBatch(batch, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
        return before - gasleft();
    }
}
