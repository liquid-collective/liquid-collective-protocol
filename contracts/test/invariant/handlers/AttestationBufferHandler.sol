// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/AttestationBuffer.sol";

/// @title AttestationBufferHandler
/// @notice Bounded action surface for the AttestationBuffer invariant suite: submit attestations,
///         veto batches (flag ids), and attempt submissions against vetoed ids — tracking ghost
///         state the invariants assert against.
contract AttestationBufferHandler is Test {
    AttestationBuffer public buffer;

    /// @notice Ghost count of successful submissions.
    uint256 public ghost_submissions;

    bytes32[] public ghost_vetoedIds;
    mapping(bytes32 => bool) public ghost_vetoed;

    constructor(AttestationBuffer _buffer) {
        buffer = _buffer;
    }

    function ghost_vetoedIdsLength() external view returns (uint256) {
        return ghost_vetoedIds.length;
    }

    function ghost_vetoedIdAt(uint256 idx) external view returns (bytes32) {
        return ghost_vetoedIds[idx];
    }

    // -----------------------------------------------------------------------
    // Actions
    // -----------------------------------------------------------------------

    function submit(bytes32 dataHash, bytes32 rootHash, bytes calldata sig) external {
        // Vetoed ids revert; they are exercised by `submitToVetoed`. Skip here so the success
        // counter stays exact.
        if (buffer.isBatchVetoed(dataHash)) return;
        buffer.submitAttestation(dataHash, rootHash, sig);
        ghost_submissions++;
    }

    function vetoBatch(bytes32 dataHash, uint256 errorCode, bytes calldata errorMessage) external {
        buffer.vetoBatch(dataHash, errorCode, errorMessage);
        if (!ghost_vetoed[dataHash]) {
            ghost_vetoed[dataHash] = true;
            ghost_vetoedIds.push(dataHash);
        }
    }

    /// @dev A submission against a vetoed id must always revert and never advance the counter.
    function submitToVetoed(uint256 seed, bytes32 rootHash, bytes calldata sig) external {
        uint256 len = ghost_vetoedIds.length;
        if (len == 0) return;
        bytes32 id = ghost_vetoedIds[bound(seed, 0, len - 1)];
        uint256 before = buffer.lastAttestationIdx();
        (bool ok,) = address(buffer).call(abi.encodeCall(buffer.submitAttestation, (id, rootHash, sig)));
        assertFalse(ok, "vetoed id accepted an attestation");
        assertEq(buffer.lastAttestationIdx(), before, "vetoed submit advanced the counter");
    }
}
