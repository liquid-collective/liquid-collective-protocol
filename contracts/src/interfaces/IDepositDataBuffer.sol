//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../libraries/BLS12_381.sol";

/// @title IDepositDataBuffer
/// @notice Interface for the DepositDataBuffer contract that stores pre-committed validator deposit batches.
/// @dev `depositDataBufferId` is `keccak256(abi.encode(batch, nonce))`, where `nonce` is the buffer's
///      ever-incrementing `lastQueuedIdx` at submission time. Folding the nonce into the id makes every
///      submission unique: byte-identical batches submitted more than once receive distinct,
///      individually-addressable ids rather than colliding.
/// @dev Replay/processed state lives on the buffer itself: the processor flips a per-batch `processed`
///      flag via `markDepositDataProcessed`, and the AttestationVerifier reads `isDepositDataProcessed`
///      to reject replays. The buffer — not the verifier — is the authoritative source for this flag.
///      In production the processor is the River deposit-execution contract.
interface IDepositDataBuffer {
    /// @notice An initial validator deposit. BLS signature is verified by the verifier and
    ///         passed to the official deposit contract; pubkey must NOT already be in
    ///         `PectraValidatorPubkeyLookup`.
    /// @dev Withdrawal credentials are NOT stored per-entry. The canonical River WC is
    ///      passed into `fetchAndValidateDeposits()` at deposit time and used both for BLS signature
    ///      verification and for the official deposit contract call, removing any need
    ///      to trust the buffer producer on this field.
    struct Deposit {
        /// @dev 48-byte BLS public key of the validator
        bytes pubkey;
        /// @dev 96-byte BLS signature over the deposit message. Verified by the verifier.
        bytes signature;
        /// @dev Deposit amount in wei (must be a multiple of 1 gwei). Typically 32 ether.
        uint256 amount;
        /// @dev Index of the node operator this deposit funds, as registered in the
        ///      OperatorsRegistry. Range-checked by River against the live operator count.
        uint256 operatorIdx;
        /// @dev Y-coordinates for BLS decompression of the pubkey + signature.
        BLS12_381.DepositY depositY;
    }

    /// @notice A top-up to an already-funded validator. BLS verification is skipped; pubkey
    ///         must already be in `PectraValidatorPubkeyLookup`.
    /// @dev No `signature` field: the beacon chain ignores BLS signatures on subsequent
    ///      deposits to an existing validator, so the consumer hardcodes 96 zero bytes
    ///      when forwarding the call to the official deposit contract.
    /// @dev No `depositY` field: BLS verification is skipped entirely for top-ups.
    struct TopUp {
        /// @dev 48-byte BLS public key of the already-funded validator
        bytes pubkey;
        /// @dev Deposit amount in wei (must be a multiple of 1 gwei). Under Pectra 0x02
        ///      credentials, may be any gwei-aligned amount up to the validator's max
        ///      effective balance.
        uint256 amount;
        /// @dev Index of the node operator this top-up funds.
        uint256 operatorIdx;
    }

    /// @notice A deposit batch — initial deposits and top-ups for a single attested submission.
    /// @dev The root signs over the nonce-bound `depositDataBufferId` (`keccak256(abi.encode(batch, nonce))`),
    ///      so the classification of each entry (initial vs top-up) is attested as part of the
    ///      buffer hash.
    struct DepositObject {
        /// @dev Initial deposits — BLS-verified, must NOT already be funded.
        Deposit[] deposits;
        /// @dev Top-ups — BLS skipped, pubkey MUST already be funded.
        TopUp[] topUps;
    }

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// @notice Emitted when a new deposit batch is submitted to the buffer.
    /// @param depositDataBufferId  The deterministic batch identifier (keccak256(abi.encode(batch, nonce)))
    /// @param nonce                The batch nonce folded into the id (the `lastQueuedIdx` at submit time)
    /// @param depositCount         Number of initial deposits in the batch
    /// @param topUpCount           Number of top-ups in the batch
    event DepositDataSubmitted(
        bytes32 indexed depositDataBufferId, uint256 nonce, uint256 depositCount, uint256 topUpCount
    );

    /// @notice Emitted when River marks a queued batch as processed.
    /// @param depositDataBufferId  The identifier of the batch that was flagged
    event DepositDataProcessed(bytes32 indexed depositDataBufferId);

    /// @notice Emitted when the admin rotates the authorized writer.
    /// @param writer  The new authorized writer address
    event SetWriter(address indexed writer);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    /// @notice Reverts when attempting to submit an empty deposit batch
    error EmptyDepositData();

    /// @notice Reverts when the computed ID already exists in the buffer
    error DepositDataBufferIdAlreadyExists(bytes32 depositDataBufferId);

    /// @notice Reverts when a requested batch ID does not exist
    error DepositDataBufferIdNotFound(bytes32 depositDataBufferId);

    /// @notice Reverts when the supplied ID does not match keccak256(abi.encode(batch, nonce))
    error DepositDataBufferIdMismatch(bytes32 expected, bytes32 computed);

    /// @notice Reverts when a batch has already been marked processed
    error DepositDataAlreadyProcessed(bytes32 depositDataBufferId);

    /// @notice Reverts when caller is not the authorized writer
    error OnlyWriter();

    /// @notice Reverts when caller is not the authorized admin
    error OnlyAdmin();

    /// @notice Reverts when caller is not the processor (the only account allowed to mark data processed)
    error OnlyProcessor();

    /// @notice Reverts when an initial-deposit pubkey is not exactly 48 bytes
    error InvalidPubkeyLength(uint256 index, uint256 length);

    /// @notice Reverts when an initial-deposit signature is not exactly 96 bytes
    error InvalidSignatureLength(uint256 index, uint256 length);

    /// @notice Reverts when a top-up pubkey is not exactly 48 bytes
    error InvalidTopUpPubkeyLength(uint256 index, uint256 length);

    /// @notice Reverts when a deposit or top-up amount is zero or not gwei-aligned
    error InvalidDepositAmount(uint256 index, uint256 amount);

    // -----------------------------------------------------------------------
    // Functions
    // -----------------------------------------------------------------------

    /// @notice Submit a deposit batch to the buffer.
    /// @dev Restricted to the writer. The buffer ID folds in the batch nonce: it MUST equal
    ///      `keccak256(abi.encode(batch, nonce))` where `nonce == lastQueuedIdx` at submit time. The
    ///      nonce is then stored so the AttestationVerifier can reconstruct and re-check the binding.
    /// @param depositDataBufferId  The expected batch ID (must equal keccak256(abi.encode(batch, nonce)))
    /// @param batch                Deposit batch containing initial deposits and top-ups
    function submitDepositData(bytes32 depositDataBufferId, DepositObject calldata batch) external;

    /// @notice Retrieve a stored deposit batch and its nonce by ID.
    /// @param depositDataBufferId  The batch identifier
    /// @return batch               The stored deposit batch
    /// @return nonce               The batch nonce folded into the id at submit time
    function getDepositData(bytes32 depositDataBufferId)
        external
        view
        returns (DepositObject memory batch, uint256 nonce);

    /// @notice Mark a queued batch as processed.
    /// @dev Restricted to the processor. Reverts if the batch is unknown or already processed, then
    ///      emits `DepositDataProcessed`.
    /// @param depositDataBufferId  The identifier of the batch to mark processed
    function markDepositDataProcessed(bytes32 depositDataBufferId) external;

    /// @notice Whether a queued batch has been marked processed.
    /// @param depositDataBufferId  The batch identifier
    /// @return True if the batch has been marked processed
    function isDepositDataProcessed(bytes32 depositDataBufferId) external view returns (bool);

    /// @notice Rotate the authorized writer. Restricted to the admin.
    /// @param newWriter  The new authorized writer address
    function setWriter(address newWriter) external;

    /// @notice Returns the authorized writer address.
    /// @return The authorized writer address
    function getWriter() external view returns (address);

    /// @notice Returns the admin address.
    /// @return The admin address
    function getAdmin() external view returns (address);

    /// @notice The processor address — the only account allowed to mark deposit data processed.
    /// @return The processor address
    function getProcessor() external view returns (address);

    /// @notice The index (and batch nonce) that will be assigned to the next submitted batch.
    /// @return The next batch nonce
    function lastQueuedIdx() external view returns (uint256);
}
