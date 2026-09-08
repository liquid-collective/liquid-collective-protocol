//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/BLS12_381.sol";

/// @title IDepositDataBufferBase
/// @notice Interface for the shared base of the DepositDataBuffer contracts that store pre-committed
///         validator deposit batches: the role management, the replay/processed state and the
///         flow-agnostic (`Standard*`) deposit types used by the shared verification logic.
/// @dev `depositDataBufferId` is `keccak256(abi.encode(batch, nonce))`, where `nonce` is the buffer's
///      ever-incrementing `lastQueuedIdx` at submission time. Folding the nonce into the id makes every
///      submission unique: byte-identical batches submitted more than once receive distinct,
///      individually-addressable ids rather than colliding.
/// @dev Replay/processed state lives on the buffer itself: the processor marks a per-batch `processed`
///      flag via `markDepositDataProcessed`, and `isDepositDataProcessed` is consulted to reject
///      replays. The buffer — not the processor — is the authoritative source for this flag. In this
///      deployment the processor is River.
interface IDepositDataBufferBase {
    /// @notice An initial validator deposit in the flow-agnostic form consumed by the shared deposit
    ///         verification logic.
    /// @dev Unlike `IDepositDataBuffer.Deposit`, the withdrawal credentials are carried per-entry so the
    ///         verification logic never has to reach for flow-specific state. They are still never
    ///         supplied by the buffer producer: the caller fills the field with the canonical
    ///         credentials it resolved itself before handing the entry over for verification.
    struct StandardDeposit {
        /// @dev 48-byte BLS public key of the validator
        bytes pubkey;
        /// @dev 96-byte BLS signature over the deposit message. Verified by the verifier.
        bytes signature;
        /// @dev Deposit amount in wei (must be a multiple of 1 gwei). Typically 32 ether.
        uint256 amount;
        /// @dev The 32-byte withdrawal credentials the deposit is verified against, resolved by the
        ///      caller rather than the buffer producer.
        bytes32 withdrawalCredentials;
        /// @dev Y-coordinates for BLS decompression of the pubkey + signature.
        BLS12_381.DepositY depositY;
    }

    /// @notice A top-up to an already-funded validator in the flow-agnostic form consumed by the shared
    ///         deposit verification logic.
    /// @dev No `signature` or `depositY` field: the beacon chain ignores BLS signatures on subsequent
    ///      deposits to an existing validator, so BLS verification is skipped entirely for top-ups.
    struct StandardTopUp {
        /// @dev 48-byte BLS public key of the already-funded validator
        bytes pubkey;
        /// @dev Deposit amount in wei (must be a multiple of 1 gwei). Since the validator
        ///      is already funded, the stateless upper bound is the 2048 ETH max effective
        ///      balance minus the 32 ETH activation balance.
        uint256 amount;
        /// @dev The 32-byte withdrawal credentials the top-up is credited against, resolved by the
        ///      caller rather than the buffer producer.
        bytes32 withdrawalCredentials;
    }

    /// @notice A deposit batch — initial deposits and top-ups — in the flow-agnostic form consumed by
    ///         the shared deposit verification logic.
    struct StandardDepositObject {
        /// @dev Initial deposits — BLS-verified, must NOT already be funded.
        StandardDeposit[] deposits;
        /// @dev Top-ups — BLS skipped, pubkey MUST already be funded.
        StandardTopUp[] topUps;
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

    /// @notice Emitted when the processor marks a queued batch as processed.
    /// @param depositDataBufferId  The identifier of the batch that was flagged
    event DepositDataProcessed(bytes32 indexed depositDataBufferId);

    /// @notice Emitted when the admin rotates the authorized producer.
    /// @param producer  The new authorized producer address
    event SetProducer(address indexed producer);

    /// @notice Emitted when the admin rotates the authorized processor.
    /// @param processor  The new authorized processor address
    event SetProcessor(address indexed processor);

    /// @notice Emitted when a new pending admin is proposed.
    /// @param pendingAdmin  The proposed pending admin address
    event SetPendingAdmin(address indexed pendingAdmin);

    /// @notice Emitted when the admin is changed (a pending admin accepts the transfer).
    /// @param admin  The new admin address
    event SetAdmin(address indexed admin);

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

    /// @notice Reverts when caller is not the authorized producer
    error OnlyProducer();

    /// @notice Reverts when caller is not the authorized admin
    error OnlyAdmin();

    /// @notice Reverts when caller is not the pending admin
    error OnlyPendingAdmin();

    /// @notice Reverts when caller is not the processor (the only account allowed to mark data processed)
    error OnlyProcessor();

    // -----------------------------------------------------------------------
    // Functions
    // -----------------------------------------------------------------------

    /// @notice Mark a queued batch as processed.
    /// @dev Restricted to the processor. Reverts if the batch is unknown or already processed, then
    ///      emits `DepositDataProcessed`.
    /// @param depositDataBufferId  The identifier of the batch to mark processed
    function markDepositDataProcessed(bytes32 depositDataBufferId) external;

    /// @notice Whether a queued batch has been marked processed.
    /// @param depositDataBufferId  The batch identifier
    /// @return True if the batch has been marked processed
    function isDepositDataProcessed(bytes32 depositDataBufferId) external view returns (bool);

    /// @notice Rotate the authorized producer. Restricted to the admin.
    /// @param newProducer  The new authorized producer address
    function setProducer(address newProducer) external;

    /// @notice Returns the authorized producer address.
    /// @return The authorized producer address
    function getProducer() external view returns (address);

    /// @notice Rotate the authorized processor. Restricted to the admin.
    /// @dev In this deployment the AttestationVerifier binds the buffer to River as its processor at
    ///      wiring time (`_assertDepositDataBufferProcessor`); rotating the processor away from that
    ///      account will make the deposit flow's `markDepositDataProcessed` call revert, so this is an
    ///      admin-trusted operation.
    /// @param newProcessor  The new authorized processor address
    function setProcessor(address newProcessor) external;

    /// @notice Propose a new admin. Restricted to the current admin.
    /// @dev Two-step transfer: the proposed admin must call `acceptAdmin` to take ownership, proving
    ///      the new address can transact. This prevents an irrecoverable transfer to a wrong address —
    ///      the buffer is immutable, so a bricked admin could never be recovered by an upgrade.
    /// @param newAdmin  The proposed pending admin address
    function proposeAdmin(address newAdmin) external;

    /// @notice Accept the admin transfer. Restricted to the pending admin.
    /// @dev Promotes the pending admin to admin and clears the pending admin.
    function acceptAdmin() external;

    /// @notice Returns the admin address.
    /// @return The admin address
    function getAdmin() external view returns (address);

    /// @notice Returns the pending admin address (zero if no transfer is in progress).
    /// @return The pending admin address
    function getPendingAdmin() external view returns (address);

    /// @notice The processor address — the only account allowed to mark deposit data processed.
    /// @return The processor address
    function getProcessor() external view returns (address);

    /// @notice The index (and batch nonce) that will be assigned to the next submitted batch.
    /// @return The next batch nonce
    function lastQueuedIdx() external view returns (uint256);
}
