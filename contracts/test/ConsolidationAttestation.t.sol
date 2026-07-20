// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/ConsolidationAttestation.sol";

/// @title ConsolidationAttestationTest
/// @notice Unit coverage for the consolidation attestation event relay and its msg.sender signature check.
contract ConsolidationAttestationTest is Test {
    bytes32 internal constant ATTEST_CONSOLIDATION_TYPEHASH = keccak256(
        "AttestConsolidation(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount,uint256[] exitEpoch)"
    );
    bytes32 internal constant ATTEST_CONSOLIDATION_ERROR_TYPEHASH = keccak256(
        "AttestConsolidationError(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount,uint256[] exitEpoch,bytes errorData)"
    );

    ConsolidationAttestation internal buffer;
    bytes32 internal domainSeparator = keccak256("consolidation-attestation-domain");

    event ConsolidationAttestationSubmitted(
        uint256 indexed idx,
        bytes32 indexed consolidationHash,
        address indexed withdrawalAddress,
        bytes[] sourcePubkeys,
        bytes[] targetPubkeys,
        uint256 totalAmount,
        uint256[] exitEpoch,
        bytes signature,
        bytes error
    );

    function setUp() public {
        buffer = new ConsolidationAttestation(domainSeparator);
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

    function _hashUintArray(uint256[] memory arr) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(arr));
    }

    /// @dev Wrap a single exit epoch in a one-element array.
    function _epochs(uint256 value) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = value;
    }

    function _expectedHash(IConsolidationAttestation.ConsolidationObject memory consolidation)
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
                _hashUintArray(consolidation.exitEpoch)
            )
        );
    }

    function _consolidation(address withdrawalAddress, uint256 seed, uint256[] memory exitEpoch)
        internal
        pure
        returns (IConsolidationAttestation.ConsolidationObject memory consolidation)
    {
        bytes[] memory sources = new bytes[](2);
        sources[0] = _pubkey(seed);
        sources[1] = _pubkey(seed + 1);

        bytes[] memory targets = new bytes[](2);
        targets[0] = _pubkey(seed + 100);
        targets[1] = _pubkey(seed + 101);

        consolidation = IConsolidationAttestation.ConsolidationObject({
            withdrawalAddress: withdrawalAddress,
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 64 ether,
            exitEpoch: exitEpoch
        });
    }

    /// @dev Digest the buffer expects the submitter to have signed.
    function _digest(IConsolidationAttestation.ConsolidationObject memory consolidation, bytes memory error)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = error.length == 0
            ? _expectedHash(consolidation)
            : keccak256(
                abi.encode(
                    ATTEST_CONSOLIDATION_ERROR_TYPEHASH,
                    consolidation.withdrawalAddress,
                    _hashBytesArray(consolidation.sourcePubkeys),
                    _hashBytesArray(consolidation.targetPubkeys),
                    consolidation.totalAmount,
                    _hashUintArray(consolidation.exitEpoch),
                    keccak256(error)
                )
            );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    /// @dev Sign the expected digest with `pk` and return a 65-byte `(r,s,v)` signature.
    function _sign(uint256 pk, IConsolidationAttestation.ConsolidationObject memory consolidation, bytes memory error)
        internal
        view
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _digest(consolidation, error));
        return abi.encodePacked(r, s, v);
    }

    function test_ExposesTypehashesAndDomainSeparator() public {
        assertEq(buffer.ATTEST_CONSOLIDATION_TYPEHASH(), ATTEST_CONSOLIDATION_TYPEHASH);
        assertEq(buffer.ATTEST_CONSOLIDATION_ERROR_TYPEHASH(), ATTEST_CONSOLIDATION_ERROR_TYPEHASH);
        assertEq(buffer.getDomainSeparator(), domainSeparator);
    }

    function test_RevertsWhenConstructedWithZeroDomainSeparator() public {
        vm.expectRevert(IConsolidationAttestation.ZeroDomainSeparator.selector);
        new ConsolidationAttestation(bytes32(0));
    }

    function test_SubmitSingle_EmitsHashObjectErrorSignatureAndIncrements() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        IConsolidationAttestation.ConsolidationObject memory c =
            _consolidation(makeAddr("withdrawal"), 1, _epochs(12345));
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
            sig,
            error
        );

        vm.prank(signer);
        buffer.submitAttestation(c, sig, error);

        assertEq(buffer.lastAttestationIdx(), 1);
    }

    function test_SubmitWithError_SignsOverConsolidationAndError() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        IConsolidationAttestation.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 5, _epochs(42));
        bytes memory error = bytes("source pubkey not exited");
        bytes memory sig = _sign(pk, c, error);
        bytes32 consolidationHash = keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_ERROR_TYPEHASH,
                c.withdrawalAddress,
                _hashBytesArray(c.sourcePubkeys),
                _hashBytesArray(c.targetPubkeys),
                c.totalAmount,
                _hashUintArray(c.exitEpoch),
                keccak256(error)
            )
        );

        vm.expectEmit(true, true, true, true);
        emit ConsolidationAttestationSubmitted(
            0,
            consolidationHash,
            c.withdrawalAddress,
            c.sourcePubkeys,
            c.targetPubkeys,
            c.totalAmount,
            c.exitEpoch,
            sig,
            error
        );

        vm.prank(signer);
        buffer.submitAttestation(c, sig, error);

        assertEq(buffer.lastAttestationIdx(), 1);
    }

    function test_IndexIncrements() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");

        assertEq(buffer.lastAttestationIdx(), 0);

        IConsolidationAttestation.ConsolidationObject memory c1 = _consolidation(address(0x1), 1, _epochs(10));
        vm.prank(signer);
        buffer.submitAttestation(c1, _sign(pk, c1, ""), "");
        assertEq(buffer.lastAttestationIdx(), 1);

        IConsolidationAttestation.ConsolidationObject memory c2 = _consolidation(address(0x2), 2, _epochs(20));
        vm.prank(signer);
        buffer.submitAttestation(c2, _sign(pk, c2, ""), "");
        assertEq(buffer.lastAttestationIdx(), 2);

        IConsolidationAttestation.ConsolidationObject memory c3 = _consolidation(address(0x3), 3, _epochs(30));
        vm.prank(signer);
        buffer.submitAttestation(c3, _sign(pk, c3, ""), "");
        assertEq(buffer.lastAttestationIdx(), 3);
    }

    function test_AnyoneCanSubmit() public {
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        (address bob, uint256 bobPk) = makeAddrAndKey("bob");
        IConsolidationAttestation.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 11, _epochs(99));

        vm.prank(alice);
        buffer.submitAttestation(c, _sign(alicePk, c, ""), "");
        assertEq(buffer.lastAttestationIdx(), 1);

        vm.prank(bob);
        buffer.submitAttestation(c, _sign(bobPk, c, ""), "");
        assertEq(buffer.lastAttestationIdx(), 2);
    }

    function test_RevertsWhenSignerIsNotMsgSender() public {
        (, uint256 signerPk) = makeAddrAndKey("signer");
        address other = makeAddr("other");
        IConsolidationAttestation.ConsolidationObject memory c =
            _consolidation(makeAddr("withdrawal"), 12, _epochs(100));
        bytes memory sig = _sign(signerPk, c, "");

        vm.expectRevert(IConsolidationAttestation.InvalidSignature.selector);
        vm.prank(other);
        buffer.submitAttestation(c, sig, "");

        assertEq(buffer.lastAttestationIdx(), 0);
    }

    function test_RevertsWhenErrorPayloadDoesNotMatchSignature() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        IConsolidationAttestation.ConsolidationObject memory c =
            _consolidation(makeAddr("withdrawal"), 13, _epochs(101));
        // Signature is over the empty-error digest, but a non-empty error is submitted.
        bytes memory sig = _sign(pk, c, "");

        vm.expectRevert(IConsolidationAttestation.InvalidSignature.selector);
        vm.prank(signer);
        buffer.submitAttestation(c, sig, bytes("mismatch"));

        assertEq(buffer.lastAttestationIdx(), 0);
    }

    function test_RevertsWhenErrorSignatureSubmittedAsApproval() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        IConsolidationAttestation.ConsolidationObject memory c =
            _consolidation(makeAddr("withdrawal"), 15, _epochs(103));
        bytes memory sig = _sign(pk, c, bytes("faulty consolidation"));

        vm.expectRevert(IConsolidationAttestation.InvalidSignature.selector);
        vm.prank(signer);
        buffer.submitAttestation(c, sig, "");

        assertEq(buffer.lastAttestationIdx(), 0);
    }

    function test_RevertsWhenSignatureUsesDifferentDomain() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        IConsolidationAttestation.ConsolidationObject memory c =
            _consolidation(makeAddr("withdrawal"), 16, _epochs(104));
        bytes32 structHash = _expectedHash(c);
        bytes32 wrongDigest = keccak256(abi.encodePacked("\x19\x01", keccak256("wrong-domain"), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, wrongDigest);

        vm.expectRevert(IConsolidationAttestation.InvalidSignature.selector);
        vm.prank(signer);
        buffer.submitAttestation(c, abi.encodePacked(r, s, v), "");
    }

    function test_ApprovalSignatureBindsExitEpoch() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        IConsolidationAttestation.ConsolidationObject memory signed =
            _consolidation(makeAddr("withdrawal"), 17, _epochs(105));
        bytes memory sig = _sign(pk, signed, "");
        IConsolidationAttestation.ConsolidationObject memory submitted = signed;
        submitted.exitEpoch[0]++;

        vm.expectRevert(IConsolidationAttestation.InvalidSignature.selector);
        vm.prank(signer);
        buffer.submitAttestation(submitted, sig, "");
    }

    function test_ErrorSignatureBindsExitEpoch() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        bytes memory error = bytes("source pubkey not exited");
        IConsolidationAttestation.ConsolidationObject memory signed =
            _consolidation(makeAddr("withdrawal"), 19, _epochs(107));
        bytes memory sig = _sign(pk, signed, error);
        IConsolidationAttestation.ConsolidationObject memory submitted = signed;
        submitted.exitEpoch[0]++;

        vm.expectRevert(IConsolidationAttestation.InvalidSignature.selector);
        vm.prank(signer);
        buffer.submitAttestation(submitted, sig, error);
    }

    function test_RevertsWhenConsolidationDoesNotMatchSignature() public {
        (address signer, uint256 pk) = makeAddrAndKey("signer");
        IConsolidationAttestation.ConsolidationObject memory signed =
            _consolidation(makeAddr("withdrawal"), 18, _epochs(106));
        bytes memory sig = _sign(pk, signed, "");
        IConsolidationAttestation.ConsolidationObject memory submitted = signed;
        submitted.totalAmount++;

        vm.expectRevert(IConsolidationAttestation.InvalidSignature.selector);
        vm.prank(signer);
        buffer.submitAttestation(submitted, sig, "");
    }

    function test_RevertsOnMalformedSignatureLength() public {
        (address signer,) = makeAddrAndKey("signer");
        IConsolidationAttestation.ConsolidationObject memory c =
            _consolidation(makeAddr("withdrawal"), 14, _epochs(102));

        vm.expectRevert(IConsolidationAttestation.InvalidSignature.selector);
        vm.prank(signer);
        buffer.submitAttestation(c, hex"deadbeef", "");
    }

    function test_HashChangesWhenExitEpochChanges() public {
        IConsolidationAttestation.ConsolidationObject memory early =
            _consolidation(makeAddr("withdrawal"), 21, _epochs(1000));
        IConsolidationAttestation.ConsolidationObject memory late =
            _consolidation(makeAddr("withdrawal"), 21, _epochs(1001));

        bytes32 earlyHash = buffer.computeConsolidationHash(early);
        bytes32 lateHash = buffer.computeConsolidationHash(late);

        assertEq(earlyHash, _expectedHash(early));
        assertEq(lateHash, _expectedHash(late));
        assertTrue(earlyHash != lateHash);
    }
}
