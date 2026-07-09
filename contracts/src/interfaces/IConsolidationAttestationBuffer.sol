//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title IConsolidationAttestationBuffer
/// @notice Interface for the ConsolidationAttestationBuffer contract, an on-chain relay that emits
///         consolidation attestation events and lets callers flag consolidation objects as errored.
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
    /// @param signature The attestor's signature.
    event ConsolidationAttestationSubmitted(
        uint256 indexed idx,
        bytes32 indexed consolidationHash,
        address indexed withdrawalAddress,
        bytes[] sourcePubkeys,
        bytes[] targetPubkeys,
        uint256 totalAmount,
        uint256 exitEpoch,
        bytes signature
    );

    /// @notice Emitted when a consolidation object is flagged as errored.
    /// @param idx The auto-incrementing index of the error.
    /// @param consolidationHash The buffer-local struct hash of the flagged consolidation object.
    /// @param raiser The account that raised the error.
    /// @param errorCode A caller-defined error code.
    /// @param errorMessage A caller-defined, free-form error message.
    /// @param invalidPubkeys Pubkeys reported invalid by the caller.
    event ConsolidationAttestationError(
        uint256 indexed idx,
        bytes32 indexed consolidationHash,
        address indexed raiser,
        uint256 errorCode,
        bytes errorMessage,
        bytes[] invalidPubkeys
    );

    /// @notice Emitted when the first error report for a consolidation hash records invalid pubkeys.
    /// @param consolidationHash The buffer-local struct hash whose first error recorded the pubkeys.
    /// @param invalidPubkeys Pubkeys recorded in the global invalid-pubkey lookup.
    event InvalidConsolidationPubkeysRecorded(bytes32 indexed consolidationHash, bytes[] invalidPubkeys);

    /// @notice Reverts when an attestation is submitted for a consolidation hash already flagged errored.
    /// @param consolidationHash The flagged consolidation hash
    error ConsolidationNotReady(bytes32 consolidationHash);

    /// @notice Reverts when an attestation is submitted with a globally invalid pubkey.
    /// @param pubkey The offending pubkey
    error InvalidConsolidationPubkey(bytes pubkey);

    /// @notice Submit an attestation for a consolidation object.
    /// @dev Reverts `ConsolidationNotReady` once the object's hash has been flagged via `raiseError`.
    ///      Reverts `InvalidConsolidationPubkey` if any source or target pubkey is in the global
    ///      invalid-pubkey lookup.
    /// @param consolidation The consolidation object being attested to.
    /// @param signature The attestor's signature over the attested data.
    function submitAttestation(ConsolidationObject calldata consolidation, bytes calldata signature) external;

    /// @notice Flag a consolidation object as errored.
    /// @dev Open by design: attribution is by `msg.sender` and the off-chain backend filters to real
    ///      daemons/committee members. A flag is sticky and makes further `submitAttestation` calls
    ///      for the same object hash revert. Re-raising an already-flagged hash is allowed and emits
    ///      again; invalid pubkey storage is first-report-wins.
    /// @param consolidation The consolidation object being flagged.
    /// @param invalidPubkeys Pubkeys reported invalid by the caller.
    /// @param errorCode A caller-defined error code.
    /// @param errorMessage A caller-defined, free-form error message.
    function raiseError(
        ConsolidationObject calldata consolidation,
        bytes[] calldata invalidPubkeys,
        uint256 errorCode,
        bytes calldata errorMessage
    ) external;

    /// @notice Compute the buffer-local struct hash of a consolidation object.
    /// @param consolidation The consolidation object to hash.
    /// @return The struct hash used for event indexing and sticky error tracking.
    function computeConsolidationHash(ConsolidationObject calldata consolidation) external pure returns (bytes32);

    /// @notice Whether a consolidation hash has been flagged errored.
    /// @param consolidationHash The consolidation hash
    /// @return True if the consolidation hash has been flagged
    function isConsolidationErrored(bytes32 consolidationHash) external view returns (bool);

    /// @notice Retrieve the first reported invalid pubkeys for a consolidation hash.
    /// @param consolidationHash The consolidation hash
    /// @return The stored invalid pubkeys
    function getInvalidPubkeys(bytes32 consolidationHash) external view returns (bytes[] memory);

    /// @notice Retrieve the count of stored invalid pubkeys for a consolidation hash.
    /// @param consolidationHash The consolidation hash
    /// @return The stored invalid pubkey count
    function invalidPubkeyCount(bytes32 consolidationHash) external view returns (uint256);

    /// @notice Retrieve one stored invalid pubkey for a consolidation hash.
    /// @param consolidationHash The consolidation hash
    /// @param index Index into the stored invalid pubkey array
    /// @return The stored invalid pubkey
    function invalidPubkeyAt(bytes32 consolidationHash, uint256 index) external view returns (bytes memory);

    /// @notice Whether a pubkey has ever been recorded by a first error report.
    /// @param pubkey The pubkey to check.
    /// @return True if the pubkey is in the global invalid-pubkey lookup.
    function isInvalidPubkey(bytes calldata pubkey) external view returns (bool);

    /// @notice Whether a pubkey hash has ever been recorded by a first error report.
    /// @param pubkeyHash The `keccak256(pubkey)` value to check.
    /// @return True if the pubkey hash is in the global invalid-pubkey lookup.
    function isInvalidPubkeyHash(bytes32 pubkeyHash) external view returns (bool);

    /// @notice Whether any source or target pubkey in a consolidation object is globally invalid.
    /// @param consolidation The consolidation object to scan.
    /// @return True if any source or target pubkey is in the global invalid-pubkey lookup.
    function hasInvalidPubkeys(ConsolidationObject calldata consolidation) external view returns (bool);

    /// @notice The index that will be assigned to the next attestation.
    function lastAttestationIdx() external view returns (uint256);

    /// @notice The index that will be assigned to the next raised error.
    function lastErrorIdx() external view returns (uint256);
}
