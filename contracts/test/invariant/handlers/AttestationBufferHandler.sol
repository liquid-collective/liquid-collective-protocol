// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/AttestationBuffer.sol";

/// @title AttestationBufferHandler
/// @notice Bounded action surface for the AttestationBuffer invariant suite: a single open `submit`
///         action, tracking the number of submissions the invariants assert against.
contract AttestationBufferHandler is Test {
    AttestationBuffer public buffer;

    /// @notice Ghost count of successful submissions.
    uint256 public ghost_submissions;

    constructor(AttestationBuffer _buffer) {
        buffer = _buffer;
    }

    function submit(bytes32 dataHash, bytes32 rootHash, bytes calldata sig) external {
        buffer.submitAttestation(dataHash, rootHash, sig);
        ghost_submissions++;
    }
}
