//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IDepositDataBuffer.sol";
import "./libraries/LibSanitize.sol";

/// @title DepositDataBuffer (v1)
/// @author Alluvial Finance Inc.
/// @notice Non-upgradeable contract that buffers pre-committed validator deposit batches on-chain.
///         A trusted producer submits batches; off-chain daemons and the AttestationVerifier read them
///         back by id. Each submission is uniquely addressable because the batch nonce (`lastQueuedIdx`
///         at submit time) is folded into the id, so byte-identical batches submitted twice never
///         collide.
/// @dev The buffer owns the authoritative `processed` flag: only the processor may flip it via
///      `markDepositDataProcessed`, and `isDepositDataProcessed` is consulted before each deposit to
///      reject replays. Withdrawal credentials are intentionally NOT stored — the canonical withdrawal
///      credentials are supplied by the processor at deposit time and used for BLS verification and the
///      official deposit-contract call, so the buffer producer is never trusted on that field.
contract DepositDataBuffer is IDepositDataBuffer {
    /// @notice Minimum amount for an initial validator deposit. Below 32 ETH a brand-new validator
    ///         never activates on the consensus layer, yet the deposit would still inflate downstream
    ///         accounting. Mirrors `AttestationVerifier`'s initial-deposit floor.
    uint256 internal constant MIN_INITIAL_DEPOSIT_AMOUNT = 32 ether;

    /// @notice Minimum amount for a top-up deposit. Mirrors `AttestationVerifier`'s top-up floor.
    uint256 internal constant MIN_TOP_UP_AMOUNT = 1 ether;

    /// @notice Maximum deposit amount — the Pectra 0x02 maximum effective balance.
    uint256 internal constant MAX_DEPOSIT_AMOUNT = 2048 ether;

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

    /// @dev depositDataBufferId => stored deposit batch.
    mapping(bytes32 => DepositObject) internal _batches;

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

    /// @inheritdoc IDepositDataBuffer
    function submitDepositData(bytes32 depositDataBufferId, DepositObject calldata batch) external onlyProducer {
        uint256 depositCount = batch.deposits.length;
        uint256 topUpCount = batch.topUps.length;
        if (depositCount == 0 && topUpCount == 0) revert EmptyDepositData();

        // Amounts must be bounded and gwei-aligned: the beacon-chain deposit contract encodes
        // amounts in gwei, so a non-aligned amount would be silently truncated downstream. Rejecting
        // here keeps the buffer consistent with the `InvalidDepositAmount` error and the verifier.
        for (uint256 i = 0; i < depositCount; i++) {
            Deposit calldata d = batch.deposits[i];
            if (d.pubkey.length != 48) revert InvalidPubkeyLength(i, d.pubkey.length);
            if (d.signature.length != 96) revert InvalidSignatureLength(i, d.signature.length);
            // Initial deposits must be gwei-aligned and within [32 ETH, 2048 ETH]: a sub-32-ETH deposit
            // never activates a validator, and 2048 ETH is the Pectra 0x02 max effective balance. This
            // mirrors the bound enforced in `AttestationVerifier.fetchAndValidateDeposits`.
            if (d.amount < MIN_INITIAL_DEPOSIT_AMOUNT || d.amount > MAX_DEPOSIT_AMOUNT || d.amount % 1 gwei != 0) {
                revert InvalidDepositAmount(i, d.amount);
            }
        }
        for (uint256 i = 0; i < topUpCount; i++) {
            TopUp calldata t = batch.topUps[i];
            if (t.pubkey.length != 48) revert InvalidTopUpPubkeyLength(i, t.pubkey.length);
            if (t.amount < MIN_TOP_UP_AMOUNT || t.amount > MAX_DEPOSIT_AMOUNT || t.amount % 1 gwei != 0) {
                revert InvalidDepositAmount(i, t.amount);
            }
        }

        // The batch nonce (lastQueuedIdx) is folded into the id, so two batches with byte-identical
        // deposit data still get distinct ids and are individually addressable. Because the nonce
        // strictly increments, every id is unique; it is stored so the AttestationVerifier can
        // reconstruct and re-check the binding after fetching the batch.
        uint256 nonce = lastQueuedIdx;
        bytes32 computedId = keccak256(abi.encode(batch, nonce));
        if (computedId != depositDataBufferId) revert DepositDataBufferIdMismatch(depositDataBufferId, computedId);
        if (_exists[computedId]) revert DepositDataBufferIdAlreadyExists(computedId);

        _batches[computedId] = batch;
        _nonce[computedId] = nonce;
        _exists[computedId] = true;
        ++lastQueuedIdx;

        emit DepositDataSubmitted(computedId, nonce, depositCount, topUpCount);
    }

    /// @inheritdoc IDepositDataBuffer
    function getDepositData(bytes32 depositDataBufferId)
        external
        view
        returns (DepositObject memory batch, uint256 nonce)
    {
        if (!_exists[depositDataBufferId]) revert DepositDataBufferIdNotFound(depositDataBufferId);
        return (_batches[depositDataBufferId], _nonce[depositDataBufferId]);
    }

    /// @inheritdoc IDepositDataBuffer
    function markDepositDataProcessed(bytes32 depositDataBufferId) external onlyProcessor {
        if (!_exists[depositDataBufferId]) revert DepositDataBufferIdNotFound(depositDataBufferId);
        if (_processed[depositDataBufferId]) revert DepositDataAlreadyProcessed(depositDataBufferId);

        _processed[depositDataBufferId] = true;

        emit DepositDataProcessed(depositDataBufferId);
    }

    /// @inheritdoc IDepositDataBuffer
    function isDepositDataProcessed(bytes32 depositDataBufferId) external view returns (bool) {
        return _processed[depositDataBufferId];
    }

    /// @inheritdoc IDepositDataBuffer
    function setProducer(address newProducer) external onlyAdmin {
        LibSanitize._notZeroAddress(newProducer);
        _producer = newProducer;
        emit SetProducer(newProducer);
    }

    /// @inheritdoc IDepositDataBuffer
    function getProducer() external view returns (address) {
        return _producer;
    }

    /// @inheritdoc IDepositDataBuffer
    function setProcessor(address newProcessor) external onlyAdmin {
        LibSanitize._notZeroAddress(newProcessor);
        _processor = newProcessor;
        emit SetProcessor(newProcessor);
    }

    /// @inheritdoc IDepositDataBuffer
    function proposeAdmin(address newAdmin) external onlyAdmin {
        LibSanitize._notZeroAddress(newAdmin);
        _pendingAdmin = newAdmin;
        emit SetPendingAdmin(newAdmin);
    }

    /// @inheritdoc IDepositDataBuffer
    function acceptAdmin() external onlyPendingAdmin {
        _admin = _pendingAdmin;
        _pendingAdmin = address(0);
        emit SetAdmin(msg.sender);
    }

    /// @inheritdoc IDepositDataBuffer
    function getAdmin() external view returns (address) {
        return _admin;
    }

    /// @inheritdoc IDepositDataBuffer
    function getPendingAdmin() external view returns (address) {
        return _pendingAdmin;
    }

    /// @inheritdoc IDepositDataBuffer
    function getProcessor() external view returns (address) {
        return _processor;
    }
}
