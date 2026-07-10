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

    constructor(ConsolidationAttestationBuffer _buffer) {
        buffer = _buffer;
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

    // -----------------------------------------------------------------------
    // Actions
    // -----------------------------------------------------------------------

    function submit(uint256 seed, uint256 exitEpoch, bytes calldata sig) external {
        if (sig.length > 128) return;

        IConsolidationAttestationBuffer.ConsolidationObject memory consolidation = _consolidation(seed, exitEpoch);

        buffer.submitAttestation(consolidation, sig);
        ghost_submissions++;
    }
}
