//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IWithdraw.1.sol";

/// @title Attestation Verifier Pectra Migration Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice One-off surface used while migrating legacy 0x01 validator pubkeys into
///         the Pectra 0x02 validator lookup.
interface IAttestationVerifierPectraMigrationV1 {
    /// @notice Emitted when a chunk of pre-Pectra validator pubkeys is migrated into verifier state.
    /// @param operatorIndex The operator whose legacy pubkeys were migrated
    /// @param startIndex The first migrated key index
    /// @param stopIndex The exclusive stop key index
    event MigratedPrePectraValidatorPubkeys(uint256 indexed operatorIndex, uint256 startIndex, uint256 stopIndex);

    /// @notice Emitted when a chunk of pre-Pectra validator pubkeys is removed from verifier state.
    /// @param pubkeys The 48-byte BLS pubkeys that were removed
    event RemovedPrePectraValidatorPubkeys(bytes[] pubkeys);

    /// @notice A legacy pubkey read during pre-Pectra migration is not 48 bytes.
    /// @param operatorIndex The operator whose key was read
    /// @param keyIndex The legacy key index
    /// @param length The observed pubkey length
    error InvalidPrePectraMigrationPubkeyLength(uint256 operatorIndex, uint256 keyIndex, uint256 length);

    /// @notice The pre-Pectra removal batch is empty.
    error InvalidPrePectraRemovalEmptyPubkeys();

    /// @notice A pubkey supplied for pre-Pectra removal is not 48 bytes.
    /// @param index The index into the removal batch
    /// @param length The observed pubkey length
    error InvalidPrePectraRemovalPubkeyLength(uint256 index, uint256 length);

    /// @notice A pre-Pectra pubkey has not been migrated into the temporary lookup.
    /// @param pubkey The 48-byte BLS pubkey
    error PrePectraValidatorPubkeyNotFunded(bytes pubkey);

    /// @notice A batch referenced a pubkey still in the pre-Pectra lookup as if it were a
    ///         Pectra validator. Migrated legacy keys must first be promoted via
    ///         self-consolidation before they can be initial-deposited or topped up.
    /// @param pubkey The offending 48-byte BLS pubkey
    error PrePectraValidatorPubkeyNotConsolidated(bytes pubkey);

    /// @notice The self consolidation batch is empty.
    error InvalidSelfConsolidationEmptyPubkeys();

    /// @notice A pubkey supplied for self consolidation is not 48 bytes.
    /// @param index The index into the self consolidation batch
    /// @param length The observed pubkey length
    error InvalidSelfConsolidationPubkeyLength(uint256 index, uint256 length);

    /// @notice Validate and prepare self-consolidation requests for pre-Pectra validator pubkeys.
    ///         Only callable by River.
    /// @dev    For each pubkey: requires membership in the pre-Pectra lookup, then promotes it to
    ///         the post-Pectra lookup (removes the pre-Pectra entry and adds a post-Pectra entry)
    ///         and builds a `src == target` self-consolidation request. The promotion reflects
    ///         the on-chain 0x01 to 0x02 upgrade so the validator is recognised by downstream
    ///         post-Pectra paths (e.g. top-ups, normal consolidations). The lookup mutations
    ///         atomically revert with the rest of the transaction if the downstream
    ///         consolidation call fails.
    /// @param pubkeys The 48-byte BLS pubkeys to consolidate
    /// @return requests The consolidation requests
    function validateSelfConsolidation(bytes[] calldata pubkeys)
        external
        returns (IWithdrawV1.ConsolidationRequest[] memory);

    /// @notice Migrate a chunk of pre-Pectra funded validator pubkeys into the verifier lookup.
    /// @dev Only callable by River admin. `stopIndex` is exclusive and must be no greater than
    ///      the operator's legacy funded validator count in OperatorsV2 storage.
    /// @param operatorIndex The operator whose legacy keys should be migrated
    /// @param startIndex The first legacy key index to migrate
    /// @param stopIndex The exclusive stop legacy key index
    function migratePrePectraValidatorPubkeys(uint256 operatorIndex, uint256 startIndex, uint256 stopIndex) external;

    /// @notice Remove a chunk of pre-Pectra funded validator pubkeys from the verifier lookup.
    /// @dev Only callable by River admin. Reverts if the batch is empty, any pubkey is not 48
    ///      bytes, or any pubkey is not currently in the pre-Pectra lookup.
    /// @param pubkeys The 48-byte BLS pubkeys to remove
    function removePrePectraValidatorPubkeys(bytes[] calldata pubkeys) external;

    /// @notice Check whether a pubkey has been migrated from pre-Pectra validator storage.
    /// @dev Intended for temporary migration and consolidation source validation; pre-Pectra
    ///      keys are not eligible top-up targets through `validateDeposits()`.
    /// @param pubkey The 48-byte BLS pubkey
    /// @return True if the pubkey is currently in the pre-Pectra lookup
    function isPrePectraValidatorPubkeyFunded(bytes calldata pubkey) external view returns (bool);
}
