//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IDepositDataBuffer.sol";
import "../libraries/BLS12_381.sol";

/// @title Attestation Verifier Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice External surface of the AttestationVerifier sibling contract that
///         River delegates to for attestation-quorum + BLS deposit-message verification
///         and for per-deposit withdrawal-credentials and committed-balance checks.
interface IAttestationVerifierV1 {
    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// @notice Emitted when the DepositDataBuffer address is updated
    event SetDepositDataBuffer(address indexed depositDataBuffer);

    /// @notice Emitted when a deposit-committee attester is added or removed
    event SetDepositCommitteeAttester(address indexed depositCommitteeAttester, bool value);

    /// @notice Emitted when the deposit-committee attestation quorum is updated
    event SetDepositCommitteeAttestationQuorum(uint256 quorum);

    /// @notice Emitted when the EIP-712 domain separator is (re)cached
    event SetDomainSeparator(bytes32 domainSeparator);

    /// @notice Emitted when the BLS deposit domain is set
    event SetDepositDomain(bytes32 depositDomain);

    /// @notice Emitted when the River address is set on this verifier
    event SetRiver(address indexed river);

    /// @notice Emitted when River records a pubkey as initial-deposited, bound to the operator
    ///         that funded it. Matches the codebase convention of emitting raw BLS pubkeys
    ///         (see `FundedValidatorKeys`, `DepositEvent`) rather than hashes.
    /// @param operatorIdx The operator that performed the initial deposit
    /// @param pubkey The 48-byte BLS pubkey of the validator
    event InitialDepositRecorded(uint256 indexed operatorIdx, bytes pubkey);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    /// @notice The number of valid, unique deposit-committee attester signatures is below the configured quorum
    /// @param valid The count of valid, unique deposit-committee attester signatures recovered
    /// @param quorum The required quorum
    error InsufficientAttestations(uint256 valid, uint256 quorum);

    /// @notice The DepositDataBuffer returned an empty deposit batch
    error NoDeposits();

    /// @notice The co-signed deposit root does not match the deposit contract's current root
    /// @param expected The deposit root co-signed by deposit-committee attesters
    /// @param actual The current root reported by the deposit contract
    error DepositRootMismatch(bytes32 expected, bytes32 actual);

    /// @notice The recomputed bufferId does not match the attested bufferId — buffer tampered post-attestation
    /// @param expected The bufferId co-signed by deposit-committee attesters
    /// @param actual The bufferId recomputed from the returned deposits
    error BufferIdMismatch(bytes32 expected, bytes32 actual);

    /// @notice The submitted signatures array exceeds MAX_SIGNATURES
    /// @param count The submitted signature count
    /// @param max The configured maximum
    error TooManySignatures(uint256 count, uint256 max);

    /// @notice A deposit's pubkey field has an unexpected byte length
    /// @param index The deposit index in the batch
    /// @param length The observed length
    error InvalidPubkeyLength(uint256 index, uint256 length);

    /// @notice A deposit's BLS signature field has an unexpected byte length
    /// @param index The deposit index in the batch
    /// @param length The observed length
    error InvalidSignatureLength(uint256 index, uint256 length);

    /// @notice The summed deposit amount exceeds the committed balance passed by River
    error NotEnoughFunds();

    /// @notice An attestation quorum of zero was supplied
    error ZeroQuorum();

    /// @notice The EIP-712 domain separator has not been initialized
    error ZeroDomainSeparator();

    /// @notice The BLS deposit domain has not been initialized
    error ZeroDepositDomain();

    /// @notice The supplied quorum is greater than the current deposit-committee attester count
    /// @param quorum The supplied quorum
    /// @param depositCommitteeAttesterCount The current deposit-committee attester count
    error QuorumExceedsDepositCommitteeAttesterCount(uint256 quorum, uint256 depositCommitteeAttesterCount);

    /// @notice The supplied quorum is greater than MAX_SIGNATURES
    /// @param quorum The supplied quorum
    /// @param max The MAX_SIGNATURES bound
    error QuorumExceedsMaxSignatures(uint256 quorum, uint256 max);

    /// @notice Adding a deposit-committee attester would exceed MAX_DEPOSIT_COMMITTEE_ATTESTERS
    /// @param count The would-be deposit-committee attester count
    /// @param max The MAX_DEPOSIT_COMMITTEE_ATTESTERS bound
    error TooManyDepositCommitteeAttesters(uint256 count, uint256 max);

    /// @notice setDepositCommitteeAttester was called with the attester already in the requested state
    /// @param depositCommitteeAttester The deposit-committee attester address
    /// @param value The requested status (matches current status)
    error DepositCommitteeAttesterStatusUnchanged(address depositCommitteeAttester, bool value);

    /// @notice A top-up referenced a pubkey that has never been initial-deposited by River.
    ///         Without this check, a malicious committee could mark an attacker pubkey as a
    ///         top-up and bypass BLS verification.
    /// @param pubkeyHash keccak256 of the offending BLS pubkey
    error TopUpPubkeyHasNoInitialDeposit(bytes32 pubkeyHash);

    /// @notice A top-up entry's operator index does not match the operator that originally
    ///         funded the validator's initial deposit. Without this bind, a compromised
    ///         deposit committee could mark a top-up against operator A's pubkey while
    ///         crediting `operator.funded` to operator B — silently desyncing on-chain
    ///         operator accounting from beacon-state stake (the validator's withdrawal
    ///         credentials are pinned in beacon state, so the ETH still lands on A, but
    ///         on-chain bookkeeping no longer reflects that).
    /// @param pubkeyHash The keccak256 hash of the offending BLS pubkey
    /// @param expectedOperatorIdx The operator index that performed the initial deposit
    /// @param actualOperatorIdx The operator index attached to the buffer's top-up entry
    error TopUpOperatorMismatch(bytes32 pubkeyHash, uint256 expectedOperatorIdx, uint256 actualOperatorIdx);

    /// @notice recordInitialDeposits was passed a pubkey already in the initial-deposit set.
    /// @param pubkeyHash keccak256 of the offending BLS pubkey
    error DuplicateInitialDeposit(bytes32 pubkeyHash);

    /// @notice recordInitialDeposits was called with parallel arrays whose lengths differ.
    ///         Each pubkey hash must be paired with exactly one operator index.
    /// @param pubkeyCount Length of the pubkeyHashes array
    /// @param operatorCount Length of the operatorIndices array
    error RecordInitialDepositsLengthMismatch(uint256 pubkeyCount, uint256 operatorCount);

    /// @notice `getFundedOperator` was queried with a pubkey not present in the initial-deposit set.
    /// @dev Mirrors the `Operators.2.OperatorNotFound` pattern used for index-keyed lookups
    ///      elsewhere in the codebase. Callers that need a non-reverting existence check should
    ///      use `hasInitialDeposit` instead.
    /// @param pubkeyHash keccak256 of the queried BLS pubkey
    error PubkeyNotFunded(bytes32 pubkeyHash);

    // -----------------------------------------------------------------------
    // Initialization
    // -----------------------------------------------------------------------

    /// @notice One-shot initializer for v1 of the AttestationVerifier.
    /// @param _river                The River proxy address; used for the EIP-712 verifyingContract
    ///                              binding and for the cross-contract admin lookup.
    /// @param _depositDataBuffer    The pre-commit buffer the keeper writes to.
    /// @param _depositCommitteeAttesters Initial set of deposit-committee attester EOAs.
    /// @param _quorum               Initial attestation quorum (1 ≤ quorum ≤ depositCommitteeAttesters.length).
    /// @param _genesisForkVersion   Genesis fork version used to derive the BLS deposit domain.
    function initAttestationVerifierV1(
        address _river,
        address _depositDataBuffer,
        address[] calldata _depositCommitteeAttesters,
        uint256 _quorum,
        bytes4 _genesisForkVersion
    ) external;

    // -----------------------------------------------------------------------
    // Validation entry point (called by River)
    // -----------------------------------------------------------------------

    /// @notice Validate attestation quorum + BLS deposit signatures, enforce per-deposit
    ///         withdrawal credentials and total-amount-vs-committed-balance, and return
    ///         the validated batch + total amount for River to execute.
    /// @dev `depositContract` is supplied by the caller (River) rather than read from the
    ///      verifier's own storage so we avoid an additional cold SLOAD per call. The same
    ///      address is used both for the front-run-resistant `get_deposit_root()` check here
    ///      and for executing `deposit{value:}()` in River, which keeps the attested root and
    ///      the executed-against contract consistent by construction.
    /// @param depositDataBufferId  Batch identifier in the DepositDataBuffer
    /// @param depositRootHash      Current deposit contract root hash co-signed by deposit-committee attesters
    /// @param signatures           EIP-712 deposit-committee attester signatures
    /// @param depositContract      The official ETH deposit contract; queried for the current root
    /// @param withdrawalCredentials The protocol-configured WC; every deposit's WC must match
    /// @param committedBalance     Total amount summed over deposits must not exceed this
    /// @return deposits            Validated deposit batch (caller executes)
    /// @return totalAmount         Sum of deposit amounts in the batch
    function validate(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        address depositContract,
        bytes32 withdrawalCredentials,
        uint256 committedBalance
    ) external view returns (IDepositDataBuffer.DepositObject[] memory deposits, uint256 totalAmount);

    // -----------------------------------------------------------------------
    // Initial-deposit recording (called by River after a successful deposit batch)
    // -----------------------------------------------------------------------

    /// @notice Record one or more pubkeys as initial-deposited, each bound to the operator
    ///         that funded it. Only callable by River.
    /// @dev Called by River after the deposit-execution loop, once per initial-deposit batch entry.
    ///      Pubkeys are passed in raw to match the codebase convention for event payloads;
    ///      the verifier hashes them internally for the mapping storage key. The recorded bind
    ///      is later consulted by the top-up branch of `_verifyBLSSignatures` to ensure subsequent
    ///      top-ups against the same pubkey are credited to the original operator
    ///      (see `TopUpOperatorMismatch`). Reverts on duplicates so a re-deposit of an already-funded
    ///      validator surfaces as an error rather than a silent ownership overwrite.
    /// @param pubkeys The 48-byte BLS pubkeys to record
    /// @param operatorIndices The operator indices that funded each pubkey (parallel to pubkeys)
    function recordInitialDeposits(bytes[] calldata pubkeys, uint256[] calldata operatorIndices) external;

    // -----------------------------------------------------------------------
    // Admin setters
    // -----------------------------------------------------------------------

    /// @notice Add or remove a deposit-committee attester. Only callable by River's admin.
    /// @param depositCommitteeAttester The deposit-committee attester address to update
    /// @param value True to register the deposit-committee attester, false to deregister
    function setDepositCommitteeAttester(address depositCommitteeAttester, bool value) external;

    /// @notice Update the deposit-committee attestation quorum. Only callable by River's admin.
    /// @param newQuorum The new quorum (1 ≤ newQuorum ≤ depositCommitteeAttesterCount, ≤ MAX_SIGNATURES)
    function setDepositCommitteeAttestationQuorum(uint256 newQuorum) external;

    /// @notice Update the DepositDataBuffer address. Only callable by River's admin.
    /// @param _depositDataBuffer The new buffer address
    function setDepositDataBuffer(address _depositDataBuffer) external;

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------

    /// @notice Check whether an address is a registered deposit-committee attester
    /// @param account The address to check
    /// @return True if account is a registered deposit-committee attester
    function isDepositCommitteeAttester(address account) external view returns (bool);

    /// @notice Retrieve the current number of registered deposit-committee attesters
    /// @return The deposit-committee attester count
    function getDepositCommitteeAttesterCount() external view returns (uint256);

    /// @notice Retrieve the current deposit-committee attestation quorum
    /// @return The required number of valid, unique deposit-committee attester signatures
    function getDepositCommitteeAttestationQuorum() external view returns (uint256);

    /// @notice Retrieve the configured DepositDataBuffer address
    /// @return The DepositDataBuffer address
    function getDepositDataBuffer() external view returns (address);

    /// @notice Retrieve the cached EIP-712 domain separator
    /// @return The EIP-712 domain separator
    function getDomainSeparator() external view returns (bytes32);

    /// @notice The BLS deposit domain.
    /// @dev Capitalized for backwards compatibility with prior public API
    /// @return The BLS deposit domain
    /// solhint-disable-next-line func-name-mixedcase
    function DEPOSIT_DOMAIN() external view returns (bytes32);

    /// @notice The River address this verifier is bound to (verifyingContract + admin source)
    /// @return The River address
    function getRiver() external view returns (address);

    /// @notice Check whether a pubkey has been initial-deposited by River.
    /// @dev Off-chain producers should subscribe to `InitialDepositRecorded` events and use
    ///      this view to confirm a pubkey is eligible for top-up submissions.
    /// @param pubkeyHash The keccak256 hash of the 48-byte BLS pubkey
    /// @return True if the pubkey is currently in the initial-deposit set
    function hasInitialDeposit(bytes32 pubkeyHash) external view returns (bool);

    /// @notice Returns the operator index that funded the initial deposit for a pubkey.
    /// @dev Reverts with `PubkeyNotFunded` if the pubkey has never been recorded.
    ///      Mirrors the `Operators.2.OperatorNotFound` revert pattern used for operator-index
    ///      lookups elsewhere in the codebase. For a non-reverting existence check, use
    ///      `hasInitialDeposit`.
    /// @param pubkeyHash The keccak256 hash of the 48-byte BLS pubkey
    /// @return operatorIdx The operator that performed the initial deposit
    function getFundedOperator(bytes32 pubkeyHash) external view returns (uint256 operatorIdx);
}
