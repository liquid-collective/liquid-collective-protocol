//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title IConsolidationAttestation
/// @notice Interface for the ConsolidationAttestation contract, an on-chain relay that emits
///         consolidation attestation events.
interface IConsolidationAttestation {
    /// @notice Buffer-local consolidation object used for off-chain attestation collection.
    /// @dev The per-consolidation `exitEpoch` array is part of the approval EIP-712 struct consumed
    ///      by L1, so it is bound by both approval and error attestation signatures.
    struct ConsolidationObject {
        /// @dev Address of the withdrawal credential that initiated the consolidation request.
        address withdrawalAddress;
        /// @dev Source validator BLS pubkeys. The buffer does not validate length or pairing.
        bytes[] sourcePubkeys;
        /// @dev Target validator BLS pubkeys. The buffer does not validate length or pairing.
        bytes[] targetPubkeys;
        /// @dev Total ETH being consolidated, in wei.
        uint256 totalAmount;
        /// @dev The exit epoch marked for each consolidation present in the object (one per pair).
        uint256[] exitEpoch;
    }

    /// @notice Emitted when a consolidation attestation is submitted.
    /// @param idx The auto-incrementing index of the attestation.
    /// @param consolidationHash The L1-compatible five-field consolidation struct hash.
    /// @param withdrawalAddress The withdrawal credential address from the consolidation object.
    /// @param sourcePubkeys The source validator BLS pubkeys from the consolidation object.
    /// @param targetPubkeys The target validator BLS pubkeys from the consolidation object.
    /// @param totalAmount The total ETH being consolidated, in wei.
    /// @param exitEpoch The exit epoch marked for each consolidation present in the object (one per pair).
    /// @param signature The attestor's signature.
    /// @param errorData A caller-supplied error payload; empty when the attestation reports no error.
    event ConsolidationAttestationSubmitted(
        uint256 indexed idx,
        bytes32 indexed consolidationHash,
        address indexed withdrawalAddress,
        bytes[] sourcePubkeys,
        bytes[] targetPubkeys,
        uint256 totalAmount,
        uint256[] exitEpoch,
        bytes signature,
        bytes errorData
    );

    /// @notice Reverts when the recovered signer of the attestation signature is not `msg.sender`.
    error InvalidSignature();

    /// @notice Reverts when the buffer is constructed with a zero domain separator.
    error ZeroDomainSeparator();

    /// @notice Submit an attestation for a consolidation object.
    /// @dev The signature must be produced by `msg.sender` over an EIP-712 digest using this buffer's
    ///      domain separator. Empty `errorData` uses the L1-compatible five-field
    ///      `AttestConsolidation` type and binds `exitEpoch`. Non-empty `errorData` uses the
    ///      distinct L2-only `AttestConsolidationError` type and binds both `exitEpoch` and
    ///      `errorData`. Reverts `InvalidSignature` otherwise.
    /// @param consolidation The consolidation object being attested to.
    /// @param signature The attestor's signature over the attested data.
    /// @param errorData A caller-supplied error payload; empty when reporting no error.
    function submitAttestation(
        ConsolidationObject calldata consolidation,
        bytes calldata signature,
        bytes calldata errorData
    ) external;

    /// @notice Compute the L1-compatible five-field struct hash of a consolidation object.
    /// @param consolidation The consolidation object to hash.
    /// @return The approval struct hash used for L1 verification and event indexing.
    function computeConsolidationHash(ConsolidationObject calldata consolidation) external pure returns (bytes32);

    /// @notice The EIP-712 domain separator used to verify attestation signatures.
    /// @return The domain separator supplied at construction.
    function getDomainSeparator() external view returns (bytes32);

    /// @notice The index that will be assigned to the next attestation.
    function lastAttestationIdx() external view returns (uint256);
}
