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
    /// @notice An initial validator deposit. BLS signature is verified by the verifier and
    ///         passed to the official deposit contract; pubkey must NOT already be in
    ///         `PectraValidatorPubkeyLookup`.
    /// @dev Withdrawal credentials are NOT stored per-entry. The canonical withdrawal credentials are
    ///      passed in by the processor at deposit time and used both for BLS signature
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
        ///      OperatorsRegistry. Range-checked by the processor against the live operator count.
        uint256 operatorIdx;
        /// @dev Y-coordinates for BLS decompression of the pubkey + signature.
        BLS12_381.DepositY depositY;
    }

    /// @notice A top-up to an already-funded validator. BLS verification is skipped; pubkey
    ///         must already be in `PectraValidatorPubkeyLookup`.
    /// @dev No `signature` field: the beacon chain ignores BLS signatures on subsequent
    ///      deposits to an existing validator, so the processor hardcodes 96 zero bytes
    ///      when forwarding the call to the official deposit contract.
    /// @dev No `depositY` field: BLS verification is skipped entirely for top-ups.
    struct TopUp {
        /// @dev 48-byte BLS public key of the already-funded validator
        bytes pubkey;
        /// @dev Deposit amount in wei (must be a multiple of 1 gwei). Since the validator
        ///      is already funded, the stateless upper bound is the 2048 ETH max effective
        ///      balance minus the 32 ETH activation balance.
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
