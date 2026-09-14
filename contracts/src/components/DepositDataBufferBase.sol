//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IDepositDataBufferBase.sol";

import "./DepositVerification.sol";

import "../libraries/LibSanitize.sol";

/// @title DepositDataBufferBase (v1)
/// @author Alluvial Finance Inc.
/// @notice Non-upgradeable contract that buffers pre-committed validator deposit batches on-chain.
///         A trusted producer submits batches; off-chain daemons and the AttestationVerifier read them
///         back by id. Each submission is uniquely addressable because the batch nonce (`lastQueuedIdx`
///         at submit time) is folded into the id, so byte-identical batches submitted twice never
///         collide.
/// @dev Base contract holding the buffer's roles, batch nonce and per-batch existence/processed state.
///      It is batch-type agnostic: the inheriting contract stores the payload, validates it with the
///      `DepositVerification` helpers and hashes it into the id it passes to `_submitDepositData`.
/// @dev The buffer owns the authoritative `processed` flag: only the processor may flip it via
///      `markDepositDataProcessed`, and `isDepositDataProcessed` is consulted before each deposit to
///      reject replays. Withdrawal credentials are intentionally NOT stored — the canonical withdrawal
///      credentials are supplied by the processor at deposit time and used for BLS verification and the
///      official deposit-contract call, so the buffer producer is never trusted on that field.
abstract contract DepositDataBufferBase is DepositVerification, IDepositDataBufferBase {
    /// @notice The processor — the only account allowed to mark deposit data processed.
    /// @dev Set at construction and rotatable by the admin via `setProcessor`. In production this is
    ///      the River deposit-execution contract, but the buffer only relies on it being the account
    ///      that consumes batches and flips their `processed` flag.
    address internal _processor;

    /// @notice The admin, able to rotate the producer, the processor, and transfer its own role.
    address internal _admin;

    /// @notice The pending admin proposed for a two-step transfer (zero when none is in progress).
    address internal _pendingAdmin;

    /// @notice The producer authorized to submit deposit batches.
    address internal _producer;

    /// @notice The index (and batch nonce) assigned to the next submitted batch.
    uint256 public lastQueuedIdx;

    /// @dev depositDataBufferId => the batch nonce folded into the id at submit time.
    mapping(bytes32 => uint256) internal _nonce;

    /// @dev depositDataBufferId => whether the batch has been submitted.
    mapping(bytes32 => bool) internal _exists;

    /// @dev depositDataBufferId => whether the batch has been marked processed by the processor.
    mapping(bytes32 => bool) internal _processed;

    /// @param admin     The admin address, able to rotate the producer.
    /// @param producer  The producer address authorized to submit deposit batches.
    /// @param processor The address permitted to mark deposit data processed.
    constructor(address admin, address producer, address processor) {
        LibSanitize._notZeroAddress(admin);
        LibSanitize._notZeroAddress(producer);
        LibSanitize._notZeroAddress(processor);
        _admin = admin;
        _producer = producer;
        _processor = processor;
    }

    /// @dev Restricts a function to the admin.
    modifier onlyAdmin() {
        if (msg.sender != _admin) revert OnlyAdmin();
        _;
    }

    /// @dev Restricts a function to the pending admin.
    modifier onlyPendingAdmin() {
        if (msg.sender != _pendingAdmin) revert OnlyPendingAdmin();
        _;
    }

    /// @dev Restricts a function to the producer.
    modifier onlyProducer() {
        if (msg.sender != _producer) revert OnlyProducer();
        _;
    }

    /// @dev Restricts a function to the processor.
    modifier onlyProcessor() {
        if (msg.sender != _processor) revert OnlyProcessor();
        _;
    }

    /// @inheritdoc IDepositDataBufferBase
    function markDepositDataProcessed(bytes32 depositDataBufferId) external onlyProcessor {
        if (!_exists[depositDataBufferId]) revert DepositDataBufferIdNotFound(depositDataBufferId);
        if (_processed[depositDataBufferId]) revert DepositDataAlreadyProcessed(depositDataBufferId);

        _processed[depositDataBufferId] = true;

        emit DepositDataProcessed(depositDataBufferId);
    }

    /// @inheritdoc IDepositDataBufferBase
    function isDepositDataProcessed(bytes32 depositDataBufferId) external view returns (bool) {
        return _processed[depositDataBufferId];
    }

    /// @inheritdoc IDepositDataBufferBase
    function setProducer(address newProducer) external onlyAdmin {
        LibSanitize._notZeroAddress(newProducer);
        _producer = newProducer;
        emit SetProducer(newProducer);
    }

    /// @inheritdoc IDepositDataBufferBase
    function getProducer() external view returns (address) {
        return _producer;
    }

    /// @inheritdoc IDepositDataBufferBase
    function setProcessor(address newProcessor) external onlyAdmin {
        LibSanitize._notZeroAddress(newProcessor);
        _processor = newProcessor;
        emit SetProcessor(newProcessor);
    }

    /// @inheritdoc IDepositDataBufferBase
    function proposeAdmin(address newAdmin) external onlyAdmin {
        LibSanitize._notZeroAddress(newAdmin);
        _pendingAdmin = newAdmin;
        emit SetPendingAdmin(newAdmin);
    }

    /// @inheritdoc IDepositDataBufferBase
    function acceptAdmin() external onlyPendingAdmin {
        _admin = _pendingAdmin;
        _pendingAdmin = address(0);
        emit SetAdmin(msg.sender);
    }

    /// @inheritdoc IDepositDataBufferBase
    function getAdmin() external view returns (address) {
        return _admin;
    }

    /// @inheritdoc IDepositDataBufferBase
    function getPendingAdmin() external view returns (address) {
        return _pendingAdmin;
    }

    /// @inheritdoc IDepositDataBufferBase
    function getProcessor() external view returns (address) {
        return _processor;
    }

    // -----------------------------------------------------------------------
    // Internal — batch submission
    // -----------------------------------------------------------------------

    /// @notice Bind a submitted deposit batch to the next batch nonce, record its existence and emit
    ///         `DepositDataSubmitted`.
    /// @dev Deliberately knows nothing about the batch type: the inheriting contract owns the payload,
    ///      validates it with the `DepositVerification` helpers and hashes it into `computedId` over
    ///      its own concrete struct. Hashing at the caller is what keeps the id byte-identical to the
    ///      one the AttestationVerifier later recomputes from the stored batch — both sides encode the
    ///      same Solidity type, so no field can silently desynchronise them.
    /// @dev The empty-batch check runs here rather than at the caller: the verification helpers are
    ///      no-ops on empty arrays, so ordering it after them is unobservable.
    /// @param depositDataBufferId The identifier claimed by the producer; must equal `computedId`.
    /// @param computedId `keccak256(abi.encode(batch, nonce))`, computed by the inheriting contract
    ///                   over its own batch type and the current `lastQueuedIdx`.
    /// @param depositCount The number of initial deposits in the batch.
    /// @param topUpCount The number of top-ups in the batch.
    function _submitDepositData(
        bytes32 depositDataBufferId,
        bytes32 computedId,
        uint256 depositCount,
        uint256 topUpCount
    ) internal {
        if (depositCount == 0 && topUpCount == 0) revert EmptyDepositData();

        // The batch nonce (lastQueuedIdx) is folded into the id, so two batches with byte-identical
        // deposit data still get distinct ids and are individually addressable. Because the nonce
        // strictly increments, every id is unique; it is stored so the AttestationVerifier can
        // reconstruct and re-check the binding after fetching the batch.
        if (computedId != depositDataBufferId) revert DepositDataBufferIdMismatch(depositDataBufferId, computedId);
        if (_exists[computedId]) revert DepositDataBufferIdAlreadyExists(computedId);

        uint256 nonce = lastQueuedIdx;
        _nonce[computedId] = nonce;
        _exists[computedId] = true;
        ++lastQueuedIdx;

        emit DepositDataSubmitted(computedId, nonce, depositCount, topUpCount);
    }
}
