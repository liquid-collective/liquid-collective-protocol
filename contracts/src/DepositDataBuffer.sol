// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import "./interfaces/IDepositDataBuffer.sol";

/// @title DepositDataBuffer
/// @notice Standalone, non-upgradeable contract where the keeper pre-commits batches of validator
///         deposit data before the attestation flow executes them on the beacon chain.
///         Access-controlled: only the authorized writer (keeper/admin) may submit batches.
contract DepositDataBuffer is IDepositDataBuffer {
    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    address private _admin;
    address private _writer;

    /// @dev depositDataBufferId → stored deposit batch
    mapping(bytes32 => DepositObject[]) private _buffer;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// @notice Emitted when the writer role is transferred
    event WriterTransferred(address indexed previousWriter, address indexed newWriter);

    /// @notice Emitted when the admin role is transferred
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error ZeroAddress();

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address admin_, address writer_) {
        if (admin_ == address(0)) revert ZeroAddress();
        if (writer_ == address(0)) revert ZeroAddress();
        _admin = admin_;
        _writer = writer_;
        emit AdminTransferred(address(0), admin_);
        emit WriterTransferred(address(0), writer_);
    }

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyWriter() {
        if (msg.sender != _writer) revert OnlyWriter();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != _admin) revert OnlyWriter(); // reuse error for simplicity
        _;
    }

    // -----------------------------------------------------------------------
    // IDepositDataBuffer
    // -----------------------------------------------------------------------

    /// @inheritdoc IDepositDataBuffer
    function submitDepositData(bytes32 depositDataBufferId, DepositObject[] calldata deposits) external onlyWriter {
        if (deposits.length == 0) revert EmptyDepositData();

        bytes32 computedId = keccak256(abi.encode(deposits));
        if (computedId != depositDataBufferId) revert DepositDataBufferIdNotFound(depositDataBufferId);

        if (_buffer[depositDataBufferId].length != 0) {
            revert DepositDataBufferIdAlreadyExists(depositDataBufferId);
        }

        DepositObject[] storage slot = _buffer[depositDataBufferId];
        for (uint256 i = 0; i < deposits.length; i++) {
            slot.push(deposits[i]);
        }

        emit DepositDataSubmitted(depositDataBufferId, deposits.length);
    }

    /// @inheritdoc IDepositDataBuffer
    function getDepositData(bytes32 depositDataBufferId) external view returns (DepositObject[] memory deposits) {
        deposits = _buffer[depositDataBufferId];
        if (deposits.length == 0) revert DepositDataBufferIdNotFound(depositDataBufferId);
    }

    /// @inheritdoc IDepositDataBuffer
    function getWriter() external view returns (address) {
        return _writer;
    }

    /// @inheritdoc IDepositDataBuffer
    function getAdmin() external view returns (address) {
        return _admin;
    }

    // -----------------------------------------------------------------------
    // Admin functions
    // -----------------------------------------------------------------------

    /// @notice Transfer the writer role to a new address.
    /// @param newWriter The new writer address
    function setWriter(address newWriter) external onlyAdmin {
        if (newWriter == address(0)) revert ZeroAddress();
        emit WriterTransferred(_writer, newWriter);
        _writer = newWriter;
    }

    /// @notice Transfer the admin role to a new address.
    /// @param newAdmin The new admin address
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        emit AdminTransferred(_admin, newAdmin);
        _admin = newAdmin;
    }
}
