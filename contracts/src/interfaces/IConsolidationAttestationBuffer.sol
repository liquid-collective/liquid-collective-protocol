//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title IConsolidationAttestationBuffer
/// @notice Interface for the ConsolidationAttestationBuffer contract, an on-chain relay that emits
///         consolidation attestation events.
interface IConsolidationAttestationBuffer {
    /// @notice Buffer-local consolidation object used for off-chain attestation collection.
    /// @dev `exitEpoch` is intentionally scoped to this buffer hash/event surface and is not part of
    ///      `IAttestationVerifierV1.ConsolidationObject`.
    struct ConsolidationObject {
        /// @dev Address of the withdrawal credential that initiated the consolidation request.
        address withdrawalAddress;
        /// @dev Source validator BLS pubkeys. The buffer does not validate length or pairing.
        bytes[] sourcePubkeys;
        /// @dev Target validator BLS pubkeys. The buffer does not validate length or pairing.
        bytes[] targetPubkeys;
        /// @dev Total ETH being consolidated, in wei.
        uint256 totalAmount;
        /// @dev Exit epoch included in the buffer-local consolidation hash.
        uint256 exitEpoch;
    }

    /// @notice Emitted when a consolidation attestation is submitted.
    /// @param idx The auto-incrementing index of the attestation.
    /// @param consolidationHash The buffer-local struct hash of the consolidation object.
    /// @param withdrawalAddress The withdrawal credential address from the consolidation object.
    /// @param sourcePubkeys The source validator BLS pubkeys from the consolidation object.
    /// @param targetPubkeys The target validator BLS pubkeys from the consolidation object.
    /// @param totalAmount The total ETH being consolidated, in wei.
    /// @param exitEpoch The exit epoch included in the buffer-local consolidation hash.
    /// @param errorData A caller-supplied error payload; empty when the attestation reports no error.
    /// @param signature The attestor's signature.
    event ConsolidationAttestationSubmitted(
        uint256 indexed idx,
        bytes32 indexed consolidationHash,
        address indexed withdrawalAddress,
        bytes[] sourcePubkeys,
        bytes[] targetPubkeys,
        uint256 totalAmount,
        uint256 exitEpoch,
        bytes errorData,
        bytes signature
    );

    /// @notice Reverts when the recovered signer of the attestation signature is not `msg.sender`.
    error InvalidSignature();

    /// @notice Submit an attestation for a consolidation object.
    /// @dev The signature must be produced by `msg.sender`. When `errorData` is empty the signed
    ///      digest is `keccak256(abi.encode(consolidation))`; when `errorData` is non-empty it is
    ///      `keccak256(abi.encode(consolidation, errorData))`. Reverts `InvalidSignature` otherwise.
    /// @param consolidation The consolidation object being attested to.
    /// @param errorData A caller-supplied error payload; empty when reporting no error.
    /// @param signature The attestor's signature over the attested data.
    function submitAttestation(
        ConsolidationObject calldata consolidation,
        bytes calldata errorData,
        bytes calldata signature
    ) external;

    /// @notice Compute the buffer-local struct hash of a consolidation object.
    /// @param consolidation The consolidation object to hash.
    /// @return The struct hash used for event indexing.
    function computeConsolidationHash(ConsolidationObject calldata consolidation) external pure returns (bytes32);

    /// @notice The index that will be assigned to the next attestation.
    function lastAttestationIdx() external view returns (uint256);
}
