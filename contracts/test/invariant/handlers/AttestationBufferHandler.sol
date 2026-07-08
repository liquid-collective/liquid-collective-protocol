// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/AttestationBuffer.sol";

/// @title AttestationBufferHandler
/// @notice Bounded action surface for the AttestationBuffer invariant suite: submit attestations,
///         raise errors (flag ids), and attempt submissions against flagged ids — tracking ghost
///         state the invariants assert against.
contract AttestationBufferHandler is Test {
    AttestationBuffer public buffer;

    /// @notice Ghost count of successful submissions.
    uint256 public ghost_submissions;

    bytes32[] public ghost_flaggedIds;
    mapping(bytes32 => bool) public ghost_flagged;

    constructor(AttestationBuffer _buffer) {
        buffer = _buffer;
    }

    function ghost_flaggedIdsLength() external view returns (uint256) {
        return ghost_flaggedIds.length;
    }

    function ghost_flaggedIdAt(uint256 idx) external view returns (bytes32) {
        return ghost_flaggedIds[idx];
    }

    // -----------------------------------------------------------------------
    // Actions
    // -----------------------------------------------------------------------

    function submit(bytes32 dataHash, bytes32 rootHash, bytes calldata sig) external {
        // Flagged ids revert; they are exercised by `submitToFlagged`. Skip here so the success
        // counter stays exact.
        if (buffer.isBatchErrored(dataHash)) return;
        buffer.submitAttestation(dataHash, rootHash, sig);
        ghost_submissions++;
    }

    function raiseError(bytes32 dataHash, uint256 errorCode, bytes calldata errorMessage) external {
        buffer.raiseError(dataHash, errorCode, errorMessage);
        if (!ghost_flagged[dataHash]) {
            ghost_flagged[dataHash] = true;
            ghost_flaggedIds.push(dataHash);
        }
    }

    /// @dev A submission against a flagged id must always revert and never advance the counter.
    function submitToFlagged(uint256 seed, bytes32 rootHash, bytes calldata sig) external {
        uint256 len = ghost_flaggedIds.length;
        if (len == 0) return;
        bytes32 id = ghost_flaggedIds[bound(seed, 0, len - 1)];
        uint256 before = buffer.lastAttestationIdx();
        (bool ok,) = address(buffer).call(abi.encodeCall(buffer.submitAttestation, (id, rootHash, sig)));
        assertFalse(ok, "flagged id accepted an attestation");
        assertEq(buffer.lastAttestationIdx(), before, "flagged submit advanced the counter");
    }
}
