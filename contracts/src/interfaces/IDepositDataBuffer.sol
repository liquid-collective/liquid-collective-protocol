//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../libraries/BLS12_381.sol";

/// @title IDepositDataBuffer
/// @notice Interface for the DepositDataBuffer contract that stores pre-committed validator deposit batches.
///
/// @dev    UNIQUENESS ASSUMPTION — every `depositDataBufferId` produced by an implementation
///         MUST be globally unique across the buffer's lifetime, even when two submissions carry
///         identical `DepositObject` contents (e.g. two top-ups to the same validator for the
///         same amount). Implementations are expected to enforce this by salting the ID with an
///         ever-incrementing counter such as `lastQueueIdx++` so collisions are impossible by
///         construction.
///
///         Why it matters: the AttestationVerifier records every successfully executed
///         `depositDataBufferId` and rejects any subsequent call referencing the same ID
///         (replay protection — critical for top-ups, whose `pubkey-in-ValidatorPubkeyLookup`
///         precondition is unchanged after the first execution). If the buffer ever reuses an
///         ID, the legitimate second batch is permanently un-executable, not just the malicious
///         replay.
interface IDepositDataBuffer {
    /// @notice An initial validator deposit. BLS signature is verified by the verifier and
    ///         passed to the official deposit contract; pubkey must NOT already be in
    ///         `ValidatorPubkeyLookup`.
    /// @dev Withdrawal credentials are NOT stored per-entry. The canonical River WC is
    ///      passed into `validate()` at deposit time and used both for BLS signature
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
    ///         must already be in `ValidatorPubkeyLookup`.
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
    /// @dev The deposit committee signs over `keccak256(abi.encode(batch))`, so the
    ///      classification of each entry (initial vs top-up) is attested as part of the
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
    /// @param depositDataBufferId  The deterministic batch identifier (keccak256 of ABI-encoded batch)
    /// @param depositCount         Number of initial deposits in the batch
    /// @param topUpCount           Number of top-ups in the batch
    event DepositDataSubmitted(bytes32 indexed depositDataBufferId, uint256 depositCount, uint256 topUpCount);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    /// @notice Reverts when attempting to submit an empty deposit batch
    error EmptyDepositData();

    /// @notice Reverts when the computed ID already exists in the buffer
    error DepositDataBufferIdAlreadyExists(bytes32 depositDataBufferId);

    /// @notice Reverts when a requested batch ID does not exist
    error DepositDataBufferIdNotFound(bytes32 depositDataBufferId);

    /// @notice Reverts when caller is not the authorized writer
    error OnlyWriter();

    // -----------------------------------------------------------------------
    // Functions
    // -----------------------------------------------------------------------

    /// @notice Submit a deposit batch to the buffer.
    /// @dev The buffer ID is computed deterministically as keccak256(abi.encode(batch)).
    /// @param depositDataBufferId  The expected batch ID (must equal keccak256(abi.encode(batch)))
    /// @param batch                Deposit batch containing initial deposits and top-ups
    function submitDepositData(bytes32 depositDataBufferId, DepositObject calldata batch) external;

    /// @notice Retrieve a stored deposit batch by its ID.
    /// @param depositDataBufferId  The batch identifier
    /// @return batch               The stored deposit batch
    function getDepositData(bytes32 depositDataBufferId) external view returns (DepositObject memory batch);

    /// @notice Returns the authorized writer address.
    /// @return The authorized writer address
    function getWriter() external view returns (address);

    /// @notice Returns the admin address.
    /// @return The admin address
    function getAdmin() external view returns (address);
}
