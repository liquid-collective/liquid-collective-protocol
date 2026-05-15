//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title IDepositDataBuffer
/// @notice Interface for the DepositDataBuffer contract that stores pre-committed validator deposit batches.
interface IDepositDataBuffer {
    /// @notice A single validator deposit object stored in the buffer.
    /// @dev Withdrawal credentials are NOT stored per-deposit. The canonical River WC is
    ///      passed into `validate()` at deposit time and used both for BLS signature
    ///      verification and for the official deposit contract call, removing any need
    ///      to trust the buffer producer on this field.
    /// @dev `isTopUp` distinguishes a top-up (subsequent deposit to an existing protocol
    ///      validator under Pectra 0x02 credentials) from an initial deposit. BLS signature
    ///      verification is skipped for top-ups because the beacon-chain deposit contract
    ///      does not enforce the signature for non-initial deposits to the same pubkey.
    ///      Authorization for this classification is delegated to the deposit committee:
    ///      the attestation quorum signs over `keccak256(abi.encode(deposits))`, so the
    ///      committee is attesting to each entry's `isTopUp` flag.
    struct DepositObject {
        /// @dev 48-byte BLS public key of the validator
        bytes pubkey;
        /// @dev 96-byte BLS signature over the deposit message. For top-ups conventionally
        ///      96 zero bytes; still feeds into `depositDataRoot` and is forwarded to the
        ///      official deposit contract.
        bytes signature;
        /// @dev Deposit amount in wei (must be a multiple of 1 gwei). For initial deposits
        ///      typically 32 ether; for top-ups under Pectra 0x02 credentials may be any
        ///      gwei-aligned amount up to the validator's max effective balance.
        uint256 amount;
        /// @dev SHA-256 deposit data root for use with the official deposit contract
        bytes32 depositDataRoot;
        /// @dev Index of the node operator this deposit funds, as registered in the
        ///      OperatorsRegistry. Range-checked by River against the live operator count.
        uint256 operatorIdx;
        /// @dev `false` for an initial deposit (BLS signature is verified). `true` for a
        ///      top-up to an existing protocol validator (BLS verification is skipped).
        ///      Default `false` is the safer default.
        bool isTopUp;
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
    /// @return The authorized writer address
    function getWriter() external view returns (address);

    /// @notice Returns the admin address.
    /// @return The admin address
    function getAdmin() external view returns (address);
}
