// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title IDepositDataBuffer
/// @notice Interface for the DepositDataBuffer contract that stores pre-committed validator deposit batches.
interface IDepositDataBuffer {
    /// @notice A single validator deposit object stored in the buffer.
    struct DepositObject {
        /// @dev 48-byte BLS public key of the validator
        bytes pubkey;
        /// @dev 96-byte BLS signature over the deposit message
        bytes signature;
        /// @dev Deposit amount in wei (must be a multiple of 1 gwei and typically 32 ether)
        uint256 amount;
        /// @dev 32-byte withdrawal credentials (abi-encoded bytes32)
        bytes withdrawalCredentials;
        /// @dev SHA-256 deposit data root for use with the official deposit contract
        bytes32 depositDataRoot;
        /// @dev Arbitrary metadata bytes32. River encodes the operator index as left-aligned ASCII:
        ///      "operator:N" zero-padded on the right. E.g. "operator:42" →
        ///      0x6f70657261746f723a3432000000000000000000000000000000000000000000
        bytes32 metadata;
    }

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// @notice Emitted when a new deposit batch is submitted to the buffer.
    /// @param depositDataBufferId  The deterministic batch identifier (keccak256 of ABI-encoded deposits)
    /// @param depositCount         Number of deposits in the batch
    event DepositDataSubmitted(bytes32 indexed depositDataBufferId, uint256 depositCount);

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

    /// @notice Submit a batch of deposit objects to the buffer.
    /// @dev The buffer ID is computed deterministically as keccak256(abi.encode(deposits)).
    /// @param depositDataBufferId  The expected batch ID (must equal keccak256(abi.encode(deposits)))
    /// @param deposits             Array of deposit objects
    function submitDepositData(bytes32 depositDataBufferId, DepositObject[] calldata deposits) external;

    /// @notice Retrieve a stored deposit batch by its ID.
    /// @param depositDataBufferId  The batch identifier
    /// @return deposits            The stored array of deposit objects
    function getDepositData(bytes32 depositDataBufferId) external view returns (DepositObject[] memory deposits);

    /// @notice Returns the authorized writer address.
    function getWriter() external view returns (address);

    /// @notice Returns the admin address.
    function getAdmin() external view returns (address);
}
