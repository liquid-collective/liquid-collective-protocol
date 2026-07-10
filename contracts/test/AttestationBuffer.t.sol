// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/AttestationBuffer.sol";

/// @title AttestationBufferTest
/// @notice Unit coverage for the AttestationBuffer signature-verifying event relay. Signatures are
///         built over the same EIP-712 domain as the L1 AttestationVerifier and must recover to the
///         submitter (`msg.sender`).
contract AttestationBufferTest is Test {
    AttestationBuffer internal buffer;

    // EIP-712 domain, constructed exactly as the L1 AttestationVerifier does.
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("DepositToConsensusLayerValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes32 internal constant ATTEST_TYPEHASH = keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");
    bytes32 internal constant ATTEST_ERROR_TYPEHASH =
        keccak256("AttestError(bytes32 depositDataBufferId,bytes32 depositRootHash,bytes errorData)");

    address internal river = makeAddr("river");
    bytes32 internal domainSeparator;

    event AttestationSubmitted(
        uint256 indexed idx,
        bytes32 indexed depositDataBufferId,
        bytes32 depositRootHash,
        bytes signature,
        bytes errorData
    );

    function setUp() public {
        domainSeparator = keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, river));
        buffer = new AttestationBuffer(domainSeparator);
    }

    // -----------------------------------------------------------------------
    // Signing helpers
    // -----------------------------------------------------------------------

    function _approvalStructHash(bytes32 id, bytes32 root) internal pure returns (bytes32) {
        return keccak256(abi.encode(ATTEST_TYPEHASH, id, root));
    }

    function _errorStructHash(bytes32 id, bytes32 root, bytes memory errorData) internal pure returns (bytes32) {
        return keccak256(abi.encode(ATTEST_ERROR_TYPEHASH, id, root, keccak256(errorData)));
    }

    function _digest(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function _sign(uint256 pk, bytes32 structHash) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _digest(structHash));
        return abi.encodePacked(r, s, v);
    }

    /// @dev Sign an approval and submit it as the signer.
    function _submitApproval(uint256 pk, bytes32 id, bytes32 root) internal returns (bytes memory sig) {
        sig = _sign(pk, _approvalStructHash(id, root));
        vm.prank(vm.addr(pk));
        buffer.submitAttestation(id, root, sig, "");
    }

    function _recover(bytes32 digest, bytes memory sig) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0, mload(add(sig, 0x60)))
        }
        return ecrecover(digest, v, r, s);
    }

    // -----------------------------------------------------------------------
    // Approval submissions
    // -----------------------------------------------------------------------

    function test_SubmitSingle() public {
        uint256 pk = 0xA11CE;
        bytes32 id = keccak256("deposit-data-1");
        bytes32 root = keccak256("deposit-root-1");
        bytes memory sig = _sign(pk, _approvalStructHash(id, root));

        vm.expectEmit(true, true, false, true);
        emit AttestationSubmitted(0, id, root, sig, "");

        vm.prank(vm.addr(pk));
        buffer.submitAttestation(id, root, sig, "");

        assertEq(buffer.lastAttestationIdx(), 1);
    }

    function test_IndexIncrements() public {
        uint256 pk = 0xA11CE;
        assertEq(buffer.lastAttestationIdx(), 0);
        _submitApproval(pk, keccak256("d1"), keccak256("r1"));
        assertEq(buffer.lastAttestationIdx(), 1);
        _submitApproval(pk, keccak256("d2"), keccak256("r2"));
        assertEq(buffer.lastAttestationIdx(), 2);
        _submitApproval(pk, keccak256("d3"), keccak256("r3"));
        assertEq(buffer.lastAttestationIdx(), 3);
    }

    /// @dev Each attester signs and submits their own attestation; all succeed.
    function test_SignerSubmitsOwnAttestation() public {
        bytes32 id = keccak256("data");
        bytes32 root = keccak256("root");

        _submitApproval(0xA11CE, id, root);
        _submitApproval(0xB0B, id, root);
        _submitApproval(0xCA1, id, root);

        assertEq(buffer.lastAttestationIdx(), 3);
    }

    function test_LastAttestationIdxStartsAtZero() public {
        assertEq(buffer.lastAttestationIdx(), 0);
    }

    // -----------------------------------------------------------------------
    // Signature verification — reverts
    // -----------------------------------------------------------------------

    /// @dev A valid signature from key A, submitted by B, reverts: recovery must equal msg.sender.
    function test_RevertWhen_SignerNotSender() public {
        uint256 pk = 0xA11CE;
        bytes32 id = keccak256("data");
        bytes32 root = keccak256("root");
        bytes memory sig = _sign(pk, _approvalStructHash(id, root));

        vm.prank(makeAddr("relayer")); // not the signer
        vm.expectRevert(IAttestationBuffer.InvalidAttestationSignature.selector);
        buffer.submitAttestation(id, root, sig, "");

        assertEq(buffer.lastAttestationIdx(), 0); // reverted → no event, index untouched
    }

    /// @dev REQUIRED: an error submission (non-empty errorData) carrying a signature over the approval
    ///      object must revert and emit nothing — the buffer verifies against the AttestError digest,
    ///      which the approval signature does not satisfy.
    function test_RevertWhen_ErrorSubmissionSignedOverApprovalObject() public {
        uint256 pk = 0xA11CE;
        bytes32 id = keccak256("bad-batch");
        bytes32 root = keccak256("root");
        bytes memory errorData = abi.encode(uint256(1), uint256(2)); // non-empty → error submission

        // Signature is over the APPROVAL struct, not the error struct.
        bytes memory sig = _sign(pk, _approvalStructHash(id, root));

        vm.prank(vm.addr(pk));
        vm.expectRevert(IAttestationBuffer.InvalidAttestationSignature.selector);
        buffer.submitAttestation(id, root, sig, errorData);

        // Revert rolls back all state and emits no event.
        assertEq(buffer.lastAttestationIdx(), 0);
    }

    /// @dev Symmetric case: an approval submission (empty errorData) with a signature over the error
    ///      object reverts.
    function test_RevertWhen_ApprovalSignedOverErrorObject() public {
        uint256 pk = 0xA11CE;
        bytes32 id = keccak256("batch");
        bytes32 root = keccak256("root");
        bytes memory errorData = abi.encode(uint256(7));

        bytes memory sig = _sign(pk, _errorStructHash(id, root, errorData));

        vm.prank(vm.addr(pk));
        vm.expectRevert(IAttestationBuffer.InvalidAttestationSignature.selector);
        buffer.submitAttestation(id, root, sig, ""); // empty → verified as approval

        assertEq(buffer.lastAttestationIdx(), 0);
    }

    // -----------------------------------------------------------------------
    // Error (faulty-batch) submissions
    // -----------------------------------------------------------------------

    function test_ErrorSubmissionEmitsErrorData() public {
        uint256 pk = 0xA11CE;
        bytes32 id = keccak256("bad-batch");
        bytes32 root = keccak256("root");
        bytes memory errorData = abi.encode(uint256(42), bytes("bad withdrawal credentials"));

        bytes memory sig = _sign(pk, _errorStructHash(id, root, errorData));

        vm.expectEmit(true, true, false, true);
        emit AttestationSubmitted(0, id, root, sig, errorData);

        vm.prank(vm.addr(pk));
        buffer.submitAttestation(id, root, sig, errorData);

        assertEq(buffer.lastAttestationIdx(), 1);
    }

    // -----------------------------------------------------------------------
    // ecrecover from event data (off-chain collection path)
    // -----------------------------------------------------------------------

    function test_EcrecoverSignerFromEvent() public {
        uint256 signerPk = 0xA11CE;
        address signer = vm.addr(signerPk);
        bytes32 id = keccak256("ecrecover-data");
        bytes32 root = keccak256("ecrecover-root");

        bytes memory sig = _sign(signerPk, _approvalStructHash(id, root));

        vm.recordLogs();
        vm.prank(signer);
        buffer.submitAttestation(id, root, sig, "");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);

        // Non-indexed event data: (depositRootHash, signature, errorData).
        (bytes32 emittedRoot, bytes memory emittedSig, bytes memory emittedErrorData) =
            abi.decode(logs[0].data, (bytes32, bytes, bytes));
        bytes32 emittedId = logs[0].topics[2];
        assertEq(emittedErrorData.length, 0);

        // Rebuild the EIP-712 digest from the emitted data alone and recover the signer.
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, emittedId, emittedRoot));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        assertEq(_recover(digest, emittedSig), signer);
    }

    // -----------------------------------------------------------------------
    // Domain separator / constructor
    // -----------------------------------------------------------------------

    function test_GetDomainSeparator() public {
        assertEq(buffer.getDomainSeparator(), domainSeparator);
    }

    function test_RevertWhen_ConstructorZeroDomainSeparator() public {
        vm.expectRevert(IAttestationBuffer.ZeroDomainSeparator.selector);
        new AttestationBuffer(bytes32(0));
    }

    // -----------------------------------------------------------------------
    // Malformed-signature recovery guards
    // -----------------------------------------------------------------------

    /// @dev A signature that is not 65 bytes recovers to address(0) and reverts.
    function test_RevertWhen_SignatureWrongLength() public {
        bytes32 id = keccak256("data");
        bytes32 root = keccak256("root");
        bytes memory badSig = hex"deadbeef"; // 4 bytes

        vm.prank(makeAddr("anyone"));
        vm.expectRevert(IAttestationBuffer.InvalidAttestationSignature.selector);
        buffer.submitAttestation(id, root, badSig, "");
    }

    /// @dev A 65-byte signature with an out-of-range `v` recovers to address(0) and reverts.
    function test_RevertWhen_InvalidV() public {
        uint256 pk = 0xA11CE;
        bytes32 id = keccak256("data");
        bytes32 root = keccak256("root");
        (, bytes32 r, bytes32 s) = vm.sign(pk, _digest(_approvalStructHash(id, root)));
        bytes memory badSig = abi.encodePacked(r, s, uint8(30)); // v neither 27 nor 28

        vm.prank(vm.addr(pk));
        vm.expectRevert(IAttestationBuffer.InvalidAttestationSignature.selector);
        buffer.submitAttestation(id, root, badSig, "");
    }

    /// @dev A signature with `v` in {0,1} is normalized to {27,28} and still verifies.
    function test_SubmitWithNormalizedLowV() public {
        uint256 pk = 0xA11CE;
        bytes32 id = keccak256("data");
        bytes32 root = keccak256("root");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _digest(_approvalStructHash(id, root)));
        bytes memory sig = abi.encodePacked(r, s, uint8(v - 27)); // 0 or 1

        vm.prank(vm.addr(pk));
        buffer.submitAttestation(id, root, sig, "");
        assertEq(buffer.lastAttestationIdx(), 1);
    }

    /// @dev A malleable high-s signature is rejected by the low-s guard (recovers to address(0)).
    function test_RevertWhen_HighSSignature() public {
        uint256 pk = 0xA11CE;
        bytes32 id = keccak256("data");
        bytes32 root = keccak256("root");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _digest(_approvalStructHash(id, root)));

        // Flip to the equivalent high-s form: s' = n - s, v' = 27<->28.
        uint256 n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
        bytes32 sHigh = bytes32(n - uint256(s));
        uint8 vFlip = v == 27 ? 28 : 27;
        bytes memory sig = abi.encodePacked(r, sHigh, vFlip);

        vm.prank(vm.addr(pk));
        vm.expectRevert(IAttestationBuffer.InvalidAttestationSignature.selector);
        buffer.submitAttestation(id, root, sig, "");
    }
}
