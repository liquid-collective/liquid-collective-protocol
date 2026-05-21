//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title IConsolidationDataBuffer
/// @notice Interface for the ConsolidationDataBuffer contract that stores pre-committed
///         EIP-7251 consolidation requests.
/// @dev    Two intentional departures from the deposit buffer pattern:
///           1. Attestor signatures live INSIDE the buffer (the `signatures` field of
///              ConsolidationObject). The verifier reads them on-chain rather than receiving
///              them as calldata. This keeps the keeper call to a single bufferId argument.
///           2. The buffer holds ONE `ConsolidationObject` per id (not an array). The
///              array-ness lives inside the struct (`sourcePubkeys[]`, `targetPubkeys[]`)
///              because a consolidation request bundles many (source, target) pairs under
///              a single initiating user.
interface IConsolidationDataBuffer {
    /// @notice A single consolidation request stored in the buffer.
    /// @dev `sourcePubkeys[i]` is consolidated INTO `targetPubkeys[i]` — same-index pairing.
    ///      `signatures` are the consolidation-committee attestor EIP-712 ECDSA signatures
    ///      over the bufferId. The bufferId itself is computed as
    ///          keccak256(abi.encode(user, sourcePubkeys, targetPubkeys, totalAmount))
    ///      with signatures EXCLUDED — this breaks the circular dependency that would
    ///      otherwise exist if signers had to sign a hash that included their own sigs.
    struct ConsolidationObject {
        /// @dev Initiator of the consolidation request; eventual recipient of LsETH.
        address user;
        /// @dev Source validator BLS pubkeys (48 bytes each). Paired by index with targetPubkeys.
        bytes[] sourcePubkeys;
        /// @dev Target validator BLS pubkeys (48 bytes each). Paired by index with sourcePubkeys.
        bytes[] targetPubkeys;
        /// @dev Total ETH being consolidated, in wei.
        uint256 totalAmount;
        /// @dev Consolidation-committee attestor EIP-712 ECDSA signatures (65 bytes each).
        ///      EXCLUDED from the bufferId hash.
        bytes[] signatures;
    }

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// @notice Emitted when a new consolidation request is submitted to the buffer.
    /// @param consolidationDataBufferId  The deterministic identifier (keccak256 of ABI-encoded
    ///                                   user + sourcePubkeys + targetPubkeys + totalAmount)
    /// @param user                       Consolidation initiator
    /// @param pairCount                  Number of (source, target) pubkey pairs
    event ConsolidationDataSubmitted(
        bytes32 indexed consolidationDataBufferId, address indexed user, uint256 pairCount
    );

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    /// @notice Reverts when attempting to submit a consolidation with zero source/target pubkeys
    error EmptyConsolidationData();

    /// @notice Reverts when the computed ID already exists in the buffer
    error ConsolidationDataBufferIdAlreadyExists(bytes32 consolidationDataBufferId);

    /// @notice Reverts when a requested ID does not exist
    error ConsolidationDataBufferIdNotFound(bytes32 consolidationDataBufferId);

    /// @notice Reverts when caller is not the authorized writer
    error OnlyWriter();

    // -----------------------------------------------------------------------
    // Functions
    // -----------------------------------------------------------------------

    /// @notice Submit a consolidation request to the buffer.
    /// @dev The bufferId is computed deterministically as
    ///      keccak256(abi.encode(user, sourcePubkeys, targetPubkeys, totalAmount)).
    ///      Signatures are excluded so attestors can sign the bufferId.
    /// @param consolidationDataBufferId  The expected bufferId
    /// @param consolidation              The consolidation object including signatures
    function submitConsolidationData(
        bytes32 consolidationDataBufferId,
        ConsolidationObject calldata consolidation
    ) external;

    /// @notice Retrieve a stored consolidation request by its ID.
    /// @param consolidationDataBufferId  The bufferId
    /// @return consolidation             The stored consolidation object
    function getConsolidationData(bytes32 consolidationDataBufferId)
        external
        view
        returns (ConsolidationObject memory consolidation);

    /// @notice Returns the authorized writer address.
    /// @return The authorized writer address
    function getWriter() external view returns (address);

    /// @notice Returns the admin address.
    /// @return The admin address
    function getAdmin() external view returns (address);
}
