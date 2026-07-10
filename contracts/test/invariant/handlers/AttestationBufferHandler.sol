// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/AttestationBuffer.sol";

/// @title AttestationBufferHandler
/// @notice Bounded action surface for the AttestationBuffer invariant suite: submit signed attestations
///         (approval when errorData is empty, faulty-batch flag otherwise). The handler holds a known
///         signer key and always produces a valid signature that recovers to itself, so every submit
///         succeeds and the invariants can assert against `ghost_submissions`.
contract AttestationBufferHandler is Test {
    AttestationBuffer public buffer;

    bytes32 internal constant ATTEST_TYPEHASH = keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");
    bytes32 internal constant ATTEST_ERROR_TYPEHASH =
        keccak256("AttestError(bytes32 depositDataBufferId,bytes32 depositRootHash,bytes errorData)");

    uint256 internal immutable signerPk;
    bytes32 internal immutable domainSeparator;

    /// @notice Ghost count of successful submissions.
    uint256 public ghost_submissions;

    constructor(AttestationBuffer _buffer, uint256 _signerPk, bytes32 _domainSeparator) {
        buffer = _buffer;
        signerPk = _signerPk;
        domainSeparator = _domainSeparator;
    }

    // -----------------------------------------------------------------------
    // Actions
    // -----------------------------------------------------------------------

    function submit(bytes32 dataHash, bytes32 rootHash, bytes calldata errorData) external {
        bytes32 structHash = errorData.length == 0
            ? keccak256(abi.encode(ATTEST_TYPEHASH, dataHash, rootHash))
            : keccak256(abi.encode(ATTEST_ERROR_TYPEHASH, dataHash, rootHash, keccak256(errorData)));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(vm.addr(signerPk));
        buffer.submitAttestation(dataHash, rootHash, sig, errorData);
        ghost_submissions++;
    }
}
