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

    /// @dev Fixed submitter whose key signs every attestation so the msg.sender check passes.
    uint256 internal immutable signerPk;
    address internal immutable signer;

    constructor(ConsolidationAttestationBuffer _buffer) {
        buffer = _buffer;
        (signer, signerPk) = makeAddrAndKey("consolidation-invariant-signer");
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

    function submit(uint256 seed, uint256 exitEpoch, bytes calldata error) external {
        if (error.length > 256) return;

        IConsolidationAttestationBuffer.ConsolidationObject memory consolidation = _consolidation(seed, exitEpoch);

        bytes32 digest =
            error.length == 0 ? keccak256(abi.encode(consolidation)) : keccak256(abi.encode(consolidation, error));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(signer);
        buffer.submitAttestation(consolidation, error, sig);
        ghost_submissions++;
    }
}
