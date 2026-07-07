//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title IAttestationBuffer
/// @notice Interface for the AttestationBuffer contract, an on-chain relay that emits attestation
///         events for off-chain collection.
interface IAttestationBuffer {
    /// @notice Emitted when an attestation is submitted.
    /// @param idx The auto-incrementing index of the attestation.
    /// @param depositDataBufferId The hash of the deposit data being attested to.
    /// @param depositRootHash The deposit root hash at the time of attestation.
    /// @param signature The attestor's signature.
    event AttestationSubmitted(
        uint256 indexed idx, bytes32 indexed depositDataBufferId, bytes32 depositRootHash, bytes signature
    );

    /// @notice Submit an attestation for a deposit data batch.
    /// @param depositDataBufferId The hash of the deposit data being attested to.
    /// @param depositRootHash The deposit root hash at the time of attestation.
    /// @param signature The attestor's signature over the attested data.
    function submitAttestation(bytes32 depositDataBufferId, bytes32 depositRootHash, bytes calldata signature) external;

    /// @notice The index that will be assigned to the next attestation.
    function lastAttestationIdx() external view returns (uint256);
}
