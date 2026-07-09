//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IAttestationBuffer.sol";

/// @title AttestationBuffer (v1)
/// @author Alluvial Finance Inc.
/// @notice A simple, non-upgradeable contract that emits attestation events on-chain.
///         Anyone can submit attestations; off-chain daemons collect the events. Signature
///         recovery (ecrecover) and quorum validation are performed elsewhere — in this protocol
///         by the AttestationVerifier, which consumes the collected signatures at deposit time.
/// @dev Unhappy path: anyone may veto a `depositDataBufferId` as not ready for deposit via
///      `vetoBatch`. Attribution is by `msg.sender` (emitted as `raiser`); the off-chain backend
///      decides whether the raiser is one of its daemons/committee members and should be listened to.
///      A veto is a sticky, hard on-chain stop — `submitAttestation` reverts for a vetoed id, so no
///      further signatures are aggregated on-chain and the backend won't assemble the deposit.
///      There is intentionally no un-veto; recovery from a bad/spam veto is to re-queue the same
///      deposits under a new nonce, which yields a fresh, unvetoed id. This contract is deployed on
///      an L2 and is self-contained — it holds no dependency on the L1 AttestationVerifier.
contract AttestationBuffer is IAttestationBuffer {
    /// @inheritdoc IAttestationBuffer
    uint256 public lastAttestationIdx;

    /// @inheritdoc IAttestationBuffer
    uint256 public lastErrorIdx;

    /// @dev depositDataBufferId => vetoed not-ready-for-deposit.
    mapping(bytes32 => bool) internal _vetoed;

    /// @inheritdoc IAttestationBuffer
    function submitAttestation(bytes32 depositDataBufferId, bytes32 depositRootHash, bytes calldata signature)
        external
    {
        if (_vetoed[depositDataBufferId]) revert BatchVetoed(depositDataBufferId);
        emit AttestationSubmitted(lastAttestationIdx, depositDataBufferId, depositRootHash, signature);
        ++lastAttestationIdx;
    }

    /// @inheritdoc IAttestationBuffer
    function vetoBatch(bytes32 depositDataBufferId, uint256 errorCode, bytes calldata errorMessage) external {
        _vetoed[depositDataBufferId] = true;
        emit AttestationError(lastErrorIdx, depositDataBufferId, msg.sender, errorCode, errorMessage);
        ++lastErrorIdx;
    }

    /// @inheritdoc IAttestationBuffer
    function isBatchVetoed(bytes32 depositDataBufferId) external view returns (bool) {
        return _vetoed[depositDataBufferId];
    }
}
