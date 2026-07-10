//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title IAttestationBuffer
/// @notice Interface for the AttestationBuffer contract, an on-chain relay that verifies and emits
///         attestation events for off-chain collection.
interface IAttestationBuffer {
    /// @notice Emitted when an attestation is submitted and its signature is verified.
    /// @param idx The auto-incrementing index of the attestation.
    /// @param depositDataBufferId The hash of the deposit data being attested to.
    /// @param depositRootHash The deposit root hash at the time of attestation.
    /// @param signature The attestor's signature (recovers to `msg.sender`).
    /// @param errorData Opaque error payload. Empty for an approval attestation; non-empty to flag the
    ///        batch as faulty and describe what is wrong (interpreted off-chain by keepers).
    event AttestationSubmitted(
        uint256 indexed idx,
        bytes32 indexed depositDataBufferId,
        bytes32 depositRootHash,
        bytes signature,
        bytes errorData
    );

    /// @notice Reverts when the recovered signer does not equal `msg.sender`.
    error InvalidAttestationSignature();

    /// @notice Reverts when the buffer is constructed with a zero domain separator.
    error ZeroDomainSeparator();

    /// @notice Submit a signed attestation for a deposit data batch.
    /// @dev The signature is verified on-chain: it must recover to `msg.sender` over the EIP-712 digest
    ///      built with this buffer's domain separator (shared with the L1 AttestationVerifier). The
    ///      signed struct depends on `errorData`:
    ///      - empty `errorData` (approval): `Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)`.
    ///        This is the digest the L1 AttestationVerifier consumes for the deposit quorum, so an
    ///        approval signature relayed off-chain is valid on L1.
    ///      - non-empty `errorData` (faulty batch): `AttestError(bytes32 depositDataBufferId,bytes32
    ///        depositRootHash,bytes errorData)`. The distinct typehash makes an error attestation inert
    ///        in the L1 deposit quorum. `errorData` is opaque to the contract (hashed and emitted).
    /// @param depositDataBufferId The hash of the deposit data being attested to.
    /// @param depositRootHash The deposit root hash at the time of attestation.
    /// @param signature The attestor's signature; must recover to `msg.sender`.
    /// @param errorData Empty for an approval; the ABI-encoded error payload for a faulty-batch flag.
    function submitAttestation(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes calldata signature,
        bytes calldata errorData
    ) external;

    /// @notice The index that will be assigned to the next attestation.
    function lastAttestationIdx() external view returns (uint256);

    /// @notice The EIP-712 domain separator used to verify attestation signatures.
    /// @dev Equals the L1 AttestationVerifier's domain separator, so a signature verified here is
    ///      consumable there.
    /// @return The domain separator.
    function getDomainSeparator() external view returns (bytes32);
}
