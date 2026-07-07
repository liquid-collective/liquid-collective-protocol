//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IAttestationBuffer.sol";

/// @title AttestationBuffer (v1)
/// @author Alluvial Finance Inc.
/// @notice A simple, non-upgradeable contract that emits attestation events on-chain.
///         Anyone can submit attestations; off-chain daemons collect the events. Signature
///         recovery (ecrecover) and quorum validation are performed elsewhere — in this protocol
///         by the AttestationVerifier, which consumes the collected signatures at deposit time —
///         so this contract intentionally performs no verification or access control.
contract AttestationBuffer is IAttestationBuffer {
    /// @inheritdoc IAttestationBuffer
    uint256 public lastAttestationIdx;

    /// @inheritdoc IAttestationBuffer
    function submitAttestation(bytes32 depositDataBufferId, bytes32 depositRootHash, bytes calldata signature)
        external
    {
        emit AttestationSubmitted(lastAttestationIdx, depositDataBufferId, depositRootHash, signature);
        ++lastAttestationIdx;
    }
}
