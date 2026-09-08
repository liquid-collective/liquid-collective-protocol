//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IDepositDataBufferBase.sol";

/// @title IDepositDataBuffer
/// @notice Interface for the DepositDataBuffer contract that stores pre-committed validator deposit batches.
/// @dev `depositDataBufferId` is `keccak256(abi.encode(batch, nonce))`, where `nonce` is the buffer's
///      ever-incrementing `lastQueuedIdx` at submission time. Folding the nonce into the id makes every
///      submission unique: byte-identical batches submitted more than once receive distinct,
///      individually-addressable ids rather than colliding.
/// @dev Replay/processed state lives on the buffer itself: the processor marks a per-batch `processed`
///      flag via `markDepositDataProcessed`, and `isDepositDataProcessed` is consulted to reject
///      replays. The buffer — not the processor — is the authoritative source for this flag. In this
///      deployment the processor is River.
interface IDepositDataBuffer is IDepositDataBufferBase {
    // -----------------------------------------------------------------------
    // Functions
    // -----------------------------------------------------------------------

    /// @notice Submit a deposit batch to the buffer.
    /// @dev Restricted to the producer. The buffer ID folds in the batch nonce: it MUST equal
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
}
