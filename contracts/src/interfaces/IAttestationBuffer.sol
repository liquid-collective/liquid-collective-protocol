//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title IAttestationBuffer
/// @notice Interface for the AttestationBuffer contract, an on-chain relay that emits attestation
///         events for off-chain collection and lets a caller flag a deposit batch as not ready.
interface IAttestationBuffer {
    /// @notice Emitted when an attestation is submitted.
    /// @param idx The auto-incrementing index of the attestation.
    /// @param depositDataBufferId The hash of the deposit data being attested to.
    /// @param depositRootHash The deposit root hash at the time of attestation.
    /// @param signature The attestor's signature.
    event AttestationSubmitted(
        uint256 indexed idx, bytes32 indexed depositDataBufferId, bytes32 depositRootHash, bytes signature
    );

    /// @notice Emitted when a deposit batch is flagged as not ready for deposit ("unhappy path").
    /// @param idx The auto-incrementing index of the error.
    /// @param depositDataBufferId The hash of the deposit data being flagged.
    /// @param raiser The account that raised the error (attribution is by msg.sender; the off-chain
    ///        backend decides whether the raiser is one of its daemons / committee members).
    /// @param errorCode A caller-defined error code (semantics owned by the off-chain backend).
    /// @param errorMessage A caller-defined, free-form error message (flexible for changing backend needs).
    event AttestationError(
        uint256 indexed idx,
        bytes32 indexed depositDataBufferId,
        address indexed raiser,
        uint256 errorCode,
        bytes errorMessage
    );

    /// @notice Reverts when an attestation is submitted for a batch already flagged not-ready.
    /// @param depositDataBufferId The flagged batch identifier
    error BatchNotReady(bytes32 depositDataBufferId);

    /// @notice Submit an attestation for a deposit data batch.
    /// @dev Reverts `BatchNotReady` once the batch has been flagged via `raiseError`.
    /// @param depositDataBufferId The hash of the deposit data being attested to.
    /// @param depositRootHash The deposit root hash at the time of attestation.
    /// @param signature The attestor's signature over the attested data.
    function submitAttestation(bytes32 depositDataBufferId, bytes32 depositRootHash, bytes calldata signature) external;

    /// @notice Flag a deposit batch as not ready for deposit ("unhappy path").
    /// @dev Open by design — attribution is by `msg.sender` and the off-chain backend filters to real
    ///      daemons/committee members. A flag is a sticky, hard on-chain stop: it makes further
    ///      `submitAttestation` for the id revert, so no more signatures are aggregated on-chain.
    ///      There is intentionally no un-flag; recovery from a bad/spam flag is to re-queue the same
    ///      deposits under a new nonce (which yields a fresh, unflagged `depositDataBufferId`).
    ///      `errorCode`/`errorMessage` are a flexible, backend-defined payload. Re-raising an already
    ///      flagged id is allowed (emits again).
    /// @param depositDataBufferId The hash of the deposit data being flagged.
    /// @param errorCode A caller-defined error code.
    /// @param errorMessage A caller-defined, free-form error message.
    function raiseError(bytes32 depositDataBufferId, uint256 errorCode, bytes calldata errorMessage) external;

    /// @notice Whether a deposit batch has been flagged not-ready.
    /// @param depositDataBufferId The batch identifier
    /// @return True if the batch has been flagged
    function isBatchErrored(bytes32 depositDataBufferId) external view returns (bool);

    /// @notice The index that will be assigned to the next attestation.
    function lastAttestationIdx() external view returns (uint256);

    /// @notice The index that will be assigned to the next raised error.
    function lastErrorIdx() external view returns (uint256);
}
