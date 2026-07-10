// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/ConsolidationAttestationBuffer.sol";

/// @title ConsolidationAttestationBufferTest
/// @notice Unit coverage for the consolidation attestation event relay and its msg.sender signature check.
contract ConsolidationAttestationBufferTest is Test {
    bytes32 internal constant ATTEST_CONSOLIDATION_TYPEHASH = keccak256(
        "AttestConsolidation(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount,uint256 exitEpoch)"
    );

    ConsolidationAttestationBuffer internal buffer;

    event ConsolidationAttestationSubmitted(
        uint256 indexed idx,
        bytes32 indexed consolidationHash,
        address indexed withdrawalAddress,
        bytes[] sourcePubkeys,
        bytes[] targetPubkeys,
        uint256 totalAmount,
        uint256 exitEpoch,
        bytes error,
        bytes signature
    );

    function setUp() public {
        buffer = new ConsolidationAttestationBuffer();
    }

    function _pubkey(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("consolidation-pubkey", seed)), bytes16(0));
    }

    function _hashBytesArray(bytes[] memory arr) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            hashes[i] = keccak256(arr[i]);
        }
        return keccak256(abi.encodePacked(hashes));
    }

    function _expectedHash(IConsolidationAttestationBuffer.ConsolidationObject memory consolidation)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_TYPEHASH,
                consolidation.withdrawalAddress,
                _hashBytesArray(consolidation.sourcePubkeys),
                _hashBytesArray(consolidation.targetPubkeys),
                consolidation.totalAmount,
                consolidation.exitEpoch
            )
        );
    }

    function _consolidation(address withdrawalAddress, uint256 seed, uint256 exitEpoch)
        internal
        pure
        returns (IConsolidationAttestationBuffer.ConsolidationObject memory consolidation)
    {
        bytes[] memory sources = new bytes[](2);
        sources[0] = _pubkey(seed);
        sources[1] = _pubkey(seed + 1);

        bytes[] memory targets = new bytes[](2);
        targets[0] = _pubkey(seed + 100);
        targets[1] = _pubkey(seed + 101);

        consolidation = IConsolidationAttestationBuffer.ConsolidationObject({
            withdrawalAddress: withdrawalAddress,
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 64 ether,
            exitEpoch: exitEpoch
        });
    }

    /// @dev Digest the buffer expects the submitter to have signed.
    function _digest(IConsolidationAttestationBuffer.ConsolidationObject memory consolidation, bytes memory error)
        internal
        pure
        returns (bytes32)
    {
        return error.length == 0 ? keccak256(abi.encode(consolidation)) : keccak256(abi.encode(consolidation, error));
    }

    /// @dev Sign the expected digest with `pk` and return a 65-byte `(r,s,v)` signature.
    function _sign(
        uint256 pk,
        IConsolidationAttestationBuffer.ConsolidationObject memory consolidation,
        bytes memory error
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _digest(consolidation, error));
        return abi.encodePacked(r, s, v);
    }

    function test_SubmitSingle_EmitsHashObjectErrorSignatureAndIncrements() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 1, 12345);
        bytes memory error = "";
        bytes memory sig = _sign(pk, c, error);
        bytes32 consolidationHash = _expectedHash(c);

        assertEq(buffer.computeConsolidationHash(c), consolidationHash);

        vm.expectEmit(true, true, true, true);
        emit ConsolidationAttestationSubmitted(
            0,
            consolidationHash,
            c.withdrawalAddress,
            c.sourcePubkeys,
            c.targetPubkeys,
            c.totalAmount,
            c.exitEpoch,
            error,
            sig
        );

        vm.prank(signer);
        buffer.submitAttestation(c, error, sig);

        assertEq(buffer.lastAttestationIdx(), 1);
    }

    function test_SubmitWithError_SignsOverConsolidationAndError() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 5, 42);
        bytes memory error = bytes("source pubkey not exited");
        bytes memory sig = _sign(pk, c, error);
        bytes32 consolidationHash = _expectedHash(c);

        vm.expectEmit(true, true, true, true);
        emit ConsolidationAttestationSubmitted(
            0,
            consolidationHash,
            c.withdrawalAddress,
            c.sourcePubkeys,
            c.targetPubkeys,
            c.totalAmount,
            c.exitEpoch,
            error,
            sig
        );

        vm.prank(signer);
        buffer.submitAttestation(c, error, sig);

        assertEq(buffer.lastAttestationIdx(), 1);
    }

    function test_IndexIncrements() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");

        assertEq(buffer.lastAttestationIdx(), 0);

        IConsolidationAttestationBuffer.ConsolidationObject memory c1 = _consolidation(address(0x1), 1, 10);
        vm.prank(signer);
        buffer.submitAttestation(c1, "", _sign(pk, c1, ""));
        assertEq(buffer.lastAttestationIdx(), 1);

        IConsolidationAttestationBuffer.ConsolidationObject memory c2 = _consolidation(address(0x2), 2, 20);
        vm.prank(signer);
        buffer.submitAttestation(c2, "", _sign(pk, c2, ""));
        assertEq(buffer.lastAttestationIdx(), 2);

        IConsolidationAttestationBuffer.ConsolidationObject memory c3 = _consolidation(address(0x3), 3, 30);
        vm.prank(signer);
        buffer.submitAttestation(c3, "", _sign(pk, c3, ""));
        assertEq(buffer.lastAttestationIdx(), 3);
    }

    function test_AnyoneCanSubmit() public {
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        (address bob, uint256 bobPk) = makeAddrAndKey("bob");
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 11, 99);

        vm.prank(alice);
        buffer.submitAttestation(c, "", _sign(alicePk, c, ""));
        assertEq(buffer.lastAttestationIdx(), 1);

        vm.prank(bob);
        buffer.submitAttestation(c, "", _sign(bobPk, c, ""));
        assertEq(buffer.lastAttestationIdx(), 2);
    }

    function test_RevertsWhenSignerIsNotMsgSender() public {
        (, uint256 signerPk) = makeAddrAndKey("signer");
        address other = makeAddr("other");
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 12, 100);
        bytes memory sig = _sign(signerPk, c, "");

        vm.expectRevert(IConsolidationAttestationBuffer.InvalidSignature.selector);
        vm.prank(other);
        buffer.submitAttestation(c, "", sig);

        assertEq(buffer.lastAttestationIdx(), 0);
    }

    function test_RevertsWhenErrorPayloadDoesNotMatchSignature() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 13, 101);
        // Signature is over the empty-error digest, but a non-empty error is submitted.
        bytes memory sig = _sign(pk, c, "");

        vm.expectRevert(IConsolidationAttestationBuffer.InvalidSignature.selector);
        vm.prank(signer);
        buffer.submitAttestation(c, bytes("mismatch"), sig);

        assertEq(buffer.lastAttestationIdx(), 0);
    }

    function test_RevertsOnMalformedSignatureLength() public {
        (address signer,) = makeAddrAndKey("signer");
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 14, 102);

        vm.expectRevert(IConsolidationAttestationBuffer.InvalidSignature.selector);
        vm.prank(signer);
        buffer.submitAttestation(c, "", hex"deadbeef");
    }

    function test_HashChangesWhenOnlyExitEpochChanges() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory early =
            _consolidation(makeAddr("withdrawal"), 21, 1000);
        IConsolidationAttestationBuffer.ConsolidationObject memory late =
            _consolidation(makeAddr("withdrawal"), 21, 1001);

        bytes32 earlyHash = buffer.computeConsolidationHash(early);
        bytes32 lateHash = buffer.computeConsolidationHash(late);

        assertEq(earlyHash, _expectedHash(early));
        assertEq(lateHash, _expectedHash(late));
        assertTrue(earlyHash != lateHash);
    }
}
