//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IAttestationBuffer.sol";

/// @title AttestationBuffer (v1)
/// @author Alluvial Finance Inc.
/// @notice A simple, non-upgradeable contract that emits attestation events on-chain.
///         Anyone can submit attestations; off-chain daemons collect the events. Signature
///         recovery (ecrecover) and quorum validation are performed elsewhere — in this protocol
///         by the AttestationVerifier, which consumes the collected signatures at deposit time.
/// @dev The buffer holds no attester-flippable state and does no verification: it is a pure event
///      relay. There is no separate veto/error channel. To flag a batch as faulty ("unhappy path"),
///      a committee member submits an ordinary attestation whose `depositRootHash` is zero — a
///      signature over `Attest(depositDataBufferId, 0)`. Off-chain the signer is recovered and
///      checked for committee membership, exactly as for a normal attestation, so the flag is
///      authenticated by the signature rather than by any on-chain access control. Such a signal is
///      inert on L1: the AttestationVerifier requires the signed root to equal the live deposit root
///      (never zero), so a zero-root attestation can never contribute to an actual deposit quorum.
///      This contract is deployed on an L2 and is self-contained — it holds no dependency on the L1
///      AttestationVerifier.
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
