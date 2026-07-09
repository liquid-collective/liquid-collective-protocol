// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/ConsolidationAttestationBuffer.sol";

/// @title ConsolidationAttestationBufferHandler
/// @notice Bounded action surface for the consolidation attestation buffer invariant suite.
contract ConsolidationAttestationBufferHandler is Test {
    ConsolidationAttestationBuffer public buffer;

    /// @notice Ghost count of successful submissions.
    uint256 public ghost_submissions;

    bytes32[] public ghost_flaggedHashes;
    mapping(bytes32 => bool) public ghost_flagged;

    bytes32[] public ghost_invalidPubkeyHashes;
    mapping(bytes32 => bool) public ghost_invalidPubkeyHash;

    constructor(ConsolidationAttestationBuffer _buffer) {
        buffer = _buffer;
    }

    function ghost_flaggedHashesLength() external view returns (uint256) {
        return ghost_flaggedHashes.length;
    }

    function ghost_flaggedHashAt(uint256 idx) external view returns (bytes32) {
        return ghost_flaggedHashes[idx];
    }

    function ghost_invalidPubkeyHashesLength() external view returns (uint256) {
        return ghost_invalidPubkeyHashes.length;
    }

    function ghost_invalidPubkeyHashAt(uint256 idx) external view returns (bytes32) {
        return ghost_invalidPubkeyHashes[idx];
    }

    function _pubkey(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("consolidation-invariant-pubkey", seed)), bytes16(0));
    }

    function _consolidation(uint256 seed, uint256 exitEpoch)
        internal
        pure
        returns (IConsolidationAttestationBuffer.ConsolidationObject memory consolidation)
    {
        uint256 count = (seed % 3) + 1;
        bytes[] memory sources = new bytes[](count);
        bytes[] memory targets = new bytes[](count);
        for (uint256 i = 0; i < count; i++) {
            sources[i] = _pubkey(seed + i);
            targets[i] = _pubkey(seed + 100 + i);
        }

        consolidation = IConsolidationAttestationBuffer.ConsolidationObject({
            withdrawalAddress: address(uint160(uint256(keccak256(abi.encode("withdrawal", seed))))),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: ((seed % 2048) + 1) * 1 ether,
            exitEpoch: exitEpoch
        });
    }

    function _invalidPubkeys(uint256 seed, uint256 count) internal pure returns (bytes[] memory invalidPubkeys) {
        invalidPubkeys = new bytes[](count);
        for (uint256 i = 0; i < count; i++) {
            invalidPubkeys[i] = _pubkey(seed + 500 + i);
        }
    }

    // -----------------------------------------------------------------------
    // Actions
    // -----------------------------------------------------------------------

    function submit(uint256 seed, uint256 exitEpoch, bytes calldata sig) external {
        if (sig.length > 128) return;

        IConsolidationAttestationBuffer.ConsolidationObject memory consolidation = _consolidation(seed, exitEpoch);
        bytes32 consolidationHash = buffer.computeConsolidationHash(consolidation);
        if (buffer.isConsolidationErrored(consolidationHash)) return;
        if (buffer.hasInvalidPubkeys(consolidation)) return;

        buffer.submitAttestation(consolidation, sig);
        ghost_submissions++;
    }

    function raiseError(
        uint256 seed,
        uint256 exitEpoch,
        uint256 invalidSeed,
        uint256 invalidCount,
        uint256 errorCode,
        bytes calldata errorMessage
    ) external {
        if (errorMessage.length > 256) return;

        IConsolidationAttestationBuffer.ConsolidationObject memory consolidation = _consolidation(seed, exitEpoch);
        bytes32 consolidationHash = buffer.computeConsolidationHash(consolidation);
        bool wasFlagged = buffer.isConsolidationErrored(consolidationHash);
        bytes[] memory invalidPubkeys = _invalidPubkeys(invalidSeed, invalidCount % 5);
        buffer.raiseError(consolidation, invalidPubkeys, errorCode, errorMessage);

        if (!ghost_flagged[consolidationHash]) {
            ghost_flagged[consolidationHash] = true;
            ghost_flaggedHashes.push(consolidationHash);
        }
        if (!wasFlagged) {
            for (uint256 i = 0; i < invalidPubkeys.length; i++) {
                bytes32 invalidPubkeyHash = keccak256(invalidPubkeys[i]);
                if (!ghost_invalidPubkeyHash[invalidPubkeyHash]) {
                    ghost_invalidPubkeyHash[invalidPubkeyHash] = true;
                    ghost_invalidPubkeyHashes.push(invalidPubkeyHash);
                }
            }
        }
    }
}
