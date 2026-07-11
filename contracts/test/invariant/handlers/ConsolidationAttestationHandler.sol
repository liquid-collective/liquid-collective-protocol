// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/ConsolidationAttestation.sol";

/// @title ConsolidationAttestationHandler
/// @notice Bounded action surface for the consolidation attestation buffer invariant suite.
contract ConsolidationAttestationHandler is Test {
    ConsolidationAttestation public buffer;

    /// @notice Ghost count of successful submissions.
    uint256 public ghost_submissions;

    /// @dev Fixed submitter whose key signs every attestation so the msg.sender check passes.
    uint256 internal immutable signerPk;
    address internal immutable signer;

    constructor(ConsolidationAttestation _buffer) {
        buffer = _buffer;
        (signer, signerPk) = makeAddrAndKey("consolidation-invariant-signer");
    }

    function _pubkey(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("consolidation-invariant-pubkey", seed)), bytes16(0));
    }

    function _consolidation(uint256 seed, uint256 exitEpoch)
        internal
        pure
        returns (IConsolidationAttestation.ConsolidationObject memory consolidation)
    {
        uint256 count = (seed % 3) + 1;
        bytes[] memory sources = new bytes[](count);
        bytes[] memory targets = new bytes[](count);
        for (uint256 i = 0; i < count; i++) {
            sources[i] = _pubkey(seed + i);
            targets[i] = _pubkey(seed + 100 + i);
        }

        consolidation = IConsolidationAttestation.ConsolidationObject({
            withdrawalAddress: address(uint160(uint256(keccak256(abi.encode("withdrawal", seed))))),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: ((seed % 2048) + 1) * 1 ether,
            exitEpoch: exitEpoch
        });
    }

    // -----------------------------------------------------------------------
    // Actions
    // -----------------------------------------------------------------------

    function submit(uint256 seed, uint256 exitEpoch, bytes calldata error) external {
        if (error.length > 256) return;

        IConsolidationAttestation.ConsolidationObject memory consolidation = _consolidation(seed, exitEpoch);

        bytes32 structHash;
        if (error.length == 0) {
            structHash = buffer.computeConsolidationHash(consolidation);
        } else {
            structHash = keccak256(
                abi.encode(
                    buffer.ATTEST_CONSOLIDATION_ERROR_TYPEHASH(),
                    consolidation.withdrawalAddress,
                    _hashBytesArray(consolidation.sourcePubkeys),
                    _hashBytesArray(consolidation.targetPubkeys),
                    consolidation.totalAmount,
                    consolidation.exitEpoch,
                    keccak256(error)
                )
            );
        }
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", buffer.getDomainSeparator(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(signer);
        buffer.submitAttestation(consolidation, sig, error);
        ghost_submissions++;
    }

    function _hashBytesArray(bytes[] memory arr) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            hashes[i] = keccak256(arr[i]);
        }
        return keccak256(abi.encodePacked(hashes));
    }
}
