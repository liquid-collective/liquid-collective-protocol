//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IDepositDataBuffer.sol";
import "./IWithdraw.1.sol";
import "../libraries/BLS12_381.sol";

/// @title Attestation Verifier Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice External surface of the AttestationVerifier sibling contract that River delegates
///         to for two independent attestation flows:
///         1. Deposit flow (`validateDeposits`) — attestation-quorum + BLS deposit-message
///            verification, plus per-deposit withdrawal-credentials and committed-balance
///            checks against a batch fetched from the `DepositDataBuffer`. View-only.
///         2. Consolidation flow (`validateConsolidation`) — attestation-quorum verification
///            over an EIP-7251 `ConsolidationObject` passed in by the caller (no on-chain
///            buffer), with replay protection on the EIP-712 structHash. State-mutating.
interface IAttestationVerifierV1 {
    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------

    /// @notice A single EIP-7251 consolidation request, passed directly into
    ///         `validateConsolidation` by the caller (no on-chain buffer indirection).
    /// @dev    `sourcePubkeys[i]` is consolidated INTO `targetPubkeys[i]` — same-index pairing.
    ///         `signatures` are the consolidation-committee attestor EIP-712 ECDSA signatures
    ///         over the typed-data struct
    ///             AttestConsolidation(address withdrawalAddress, bytes[] sourcePubkeys, bytes[] targetPubkeys, uint256 totalAmount)
    ///         The `signatures` field itself is NOT part of the typed data — only the four
    ///         request fields are. This is what lets attestors produce signatures over the
    ///         request without a circular dependency.
    struct ConsolidationObject {
        /// @dev Address of the withdrawal credential that initiated the consolidation request; eventual recipient of LsETH unless the mapping is set to a different address
        address withdrawalAddress;
        /// @dev Source validator BLS pubkeys (48 bytes each). Paired by index with targetPubkeys.
        bytes[] sourcePubkeys;
        /// @dev Target validator BLS pubkeys (48 bytes each). Paired by index with sourcePubkeys.
        bytes[] targetPubkeys;
        /// @dev Total ETH being consolidated, in wei.
        uint256 totalAmount;
        /// @dev Consolidation-committee attestor EIP-712 ECDSA signatures (65 bytes each).
        ///      Not part of the EIP-712 typed data the committee signs.
        bytes[] signatures;
    }

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// @notice Emitted when the DepositDataBuffer address is updated
    event SetDepositDataBuffer(address indexed depositDataBuffer);

    /// @notice Emitted when a root attester is added or removed
    event SetRootAttester(address indexed rootAttester, bool value);

    /// @notice Emitted when the root attestation quorum is updated
    event SetRootAttestationQuorum(uint256 quorum);

    /// @notice Emitted when the EIP-712 domain separator is (re)cached
    event SetDomainSeparator(bytes32 domainSeparator);

    /// @notice Emitted when the BLS deposit domain is set
    event SetDepositDomain(bytes32 depositDomain);

    /// @notice Emitted when the River address is set on this verifier
    event SetRiver(address indexed river);

    /// @notice Emitted when a consolidation-committee attester is added or removed
    event SetConsolidationCommitteeAttester(address indexed consolidationCommitteeAttester, bool value);

    /// @notice Emitted when the consolidation-committee attestation quorum is updated
    event SetConsolidationCommitteeAttestationQuorum(uint256 quorum);

    /// @notice Emitted when the EIP-712 consolidation domain separator is (re)cached
    event SetConsolidationDomainSeparator(bytes32 consolidationDomainSeparator);

    /// @notice Emitted when a consolidation request is successfully validated and
    ///         marked as processed for replay protection.
    /// @param consolidationHash The EIP-712 structHash of the consolidation request
    event ConsolidationProcessed(bytes32 indexed consolidationHash);

    /// @notice Emitted when a chunk of pre-Pectra validator pubkeys is migrated into verifier state.
    /// @param operatorIndex The operator whose legacy pubkeys were migrated
    /// @param startIndex The first migrated key index
    /// @param stopIndex The exclusive stop key index
    event MigratedPrePectraValidatorPubkeys(uint256 indexed operatorIndex, uint256 startIndex, uint256 stopIndex);

    /// @notice Emitted when a chunk of pre-Pectra validator pubkeys is removed from verifier state.
    /// @param pubkeys The 48-byte BLS pubkeys that were removed
    event RemovedPrePectraValidatorPubkeys(bytes[] pubkeys);

    /// @notice Emitted when a batch of validator pubkeys is added to the post-Pectra lookup.
    /// @dev    Fires on every path that records membership in `PectraValidatorPubkeyLookup`:
    ///           - `recordNewlyFundedPubkeys` (initial-deposit callback from River),
    ///           - `validateSelfConsolidation` (self-consolidation upgrade; pubkeys are
    ///             simultaneously cleared from the pre-Pectra lookup — see
    ///             `RemovedPrePectraValidatorPubkeys` paired emission semantics).
    /// @param pubkeys The 48-byte BLS pubkeys that were added
    event AddedPectraValidatorPubkeys(bytes[] pubkeys);

    /// @notice Emitted when a batch of validator pubkeys is removed from the post-Pectra lookup.
    /// @dev    Reserved for future EL-withdrawal code that clears membership when a validator
    ///         exits and is no longer controlled by the protocol. No on-chain path emits this
    ///         today; the declaration is here so future callers stay consistent with the
    ///         existing `Added` / `Removed` symmetry on the pre-Pectra side.
    /// @param pubkeys The 48-byte BLS pubkeys that were removed
    event RemovedPectraValidatorPubkeys(bytes[] pubkeys);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    /// @notice The number of valid, unique root attester signatures is below the configured quorum
    /// @param valid The count of valid, unique root attester signatures recovered
    /// @param quorum The required quorum
    error InsufficientAttestations(uint256 valid, uint256 quorum);

    /// @notice The DepositDataBuffer returned an empty deposit batch
    error NoDeposits();

    /// @notice The co-signed deposit root does not match the deposit contract's current root
    /// @param expected The deposit root co-signed by root attesters
    /// @param actual The current root reported by the deposit contract
    error DepositRootMismatch(bytes32 expected, bytes32 actual);

    /// @notice The recomputed bufferId does not match the attested bufferId — buffer tampered post-attestation
    /// @param expected The bufferId co-signed by root attesters
    /// @param actual The bufferId recomputed from the returned deposits
    error BufferIdMismatch(bytes32 expected, bytes32 actual);

    /// @notice The supplied deposit data buffer ID has already been processed.
    /// @param depositDataBufferId The replayed deposit data buffer ID
    error DepositDataBufferIdAlreadyProcessed(bytes32 depositDataBufferId);

    /// @notice The submitted signatures array exceeds MAX_SIGNATURES
    /// @param count The submitted signature count
    /// @param max The configured maximum
    error TooManySignatures(uint256 count, uint256 max);

    /// @notice An external caller invoked a function reserved for self-staticcall trampolining.
    error OnlySelfCall();

    /// @notice An entry's pubkey field has an unexpected byte length
    /// @param index Index into the sub-array currently being validated
    ///              (either `batch.deposits` or `batch.topUps`); the loop that raised
    ///              the revert determines which.
    /// @param length The observed length
    error InvalidPubkeyLength(uint256 index, uint256 length);

    /// @notice A deposit's BLS signature field has an unexpected byte length
    /// @dev Only raised while iterating `batch.deposits` — top-ups have no signature field.
    /// @param index Index into `batch.deposits`
    /// @param length The observed length
    error InvalidSignatureLength(uint256 index, uint256 length);

    /// @notice An entry's `amount` is outside the protocol-accepted range
    ///         [1 ether, 2048 ether] or is not gwei-aligned. Enforced here in
    ///         `validateDeposits()` so producer bugs fail before the heavy BLS path runs;
    ///         downstream `_depositValidator` trusts this check.
    /// @param index Index into the sub-array currently being validated
    ///              (either `batch.deposits` or `batch.topUps`); the loop that raised
    ///              the revert determines which.
    /// @param amount The offending amount in wei
    error InvalidDepositAmount(uint256 index, uint256 amount);

    /// @notice The summed deposit amount exceeds the committed balance passed by River
    error NotEnoughFunds();

    /// @notice An attestation quorum of zero was supplied
    error ZeroQuorum();

    /// @notice The EIP-712 domain separator has not been initialized
    error ZeroDomainSeparator();

    /// @notice The BLS deposit domain has not been initialized
    error ZeroDepositDomain();

    /// @notice The supplied quorum is greater than the current root attester count
    /// @param quorum The supplied quorum
    /// @param rootAttesterCount The current root attester count
    error QuorumExceedsRootAttesterCount(uint256 quorum, uint256 rootAttesterCount);

    /// @notice The supplied quorum is greater than MAX_SIGNATURES
    /// @param quorum The supplied quorum
    /// @param max The MAX_SIGNATURES bound
    error QuorumExceedsMaxSignatures(uint256 quorum, uint256 max);

    /// @notice Adding a root attester would exceed MAX_ROOT_ATTESTERS
    /// @param count The would-be root attester count
    /// @param max The MAX_ROOT_ATTESTERS bound
    error TooManyRootAttesters(uint256 count, uint256 max);

    /// @notice setRootAttester was called with the attester already in the requested state
    /// @param rootAttester The root attester address
    /// @param value The requested status (matches current status)
    error RootAttesterStatusUnchanged(address rootAttester, bool value);

    // -- Consolidation-side errors --

    /// @notice The number of valid, unique consolidation-committee attester signatures is below the configured quorum
    /// @param valid The count of valid, unique consolidation-committee attester signatures recovered
    /// @param quorum The required quorum
    error InsufficientConsolidationAttestations(uint256 valid, uint256 quorum);

    /// @notice The consolidation request has zero source pubkeys
    error NoConsolidations();

    /// @notice The source and target pubkey arrays have different lengths
    /// @param sourceLength The length of the source pubkey array
    /// @param targetLength The length of the target pubkey array
    error ConsolidationArrayLengthMismatch(uint256 sourceLength, uint256 targetLength);

    /// @notice A pubkey field has an unexpected byte length
    /// @param index The pair index
    /// @param length The observed length
    /// @param isSource True if the offending pubkey is the source pubkey, false if it is the target pubkey
    error InvalidConsolidationPubkeyLength(uint256 index, uint256 length, bool isSource);

    /// @notice The EIP-712 consolidation domain separator has not been initialized
    error ZeroConsolidationDomainSeparator();

    /// @notice The consolidation's withdrawal address is the zero address
    error ZeroConsolidationWithdrawalAddress();

    /// @notice Adding a consolidation-committee attester would exceed MAX_CONSOLIDATION_COMMITTEE_ATTESTERS
    /// @param count The would-be consolidation-committee attester count
    /// @param max The MAX_CONSOLIDATION_COMMITTEE_ATTESTERS bound
    error TooManyConsolidationCommitteeAttesters(uint256 count, uint256 max);

    /// @notice setConsolidationCommitteeAttester was called with the attester already in the requested state
    /// @param consolidationCommitteeAttester The consolidation-committee attester address
    /// @param value The requested status (matches current status)
    error ConsolidationCommitteeAttesterStatusUnchanged(address consolidationCommitteeAttester, bool value);

    // -- Consolidation-side errors --

    /// @notice The consolidation's totalAmount is zero
    error ZeroConsolidationTotalAmount();

    /// @notice The supplied quorum is greater than the current consolidation-committee attester count
    /// @param quorum The supplied quorum
    /// @param consolidationCommitteeAttesterCount The current consolidation-committee attester count
    error QuorumExceedsConsolidationCommitteeAttesterCount(uint256 quorum, uint256 consolidationCommitteeAttesterCount);

    /// @notice The supplied consolidation has already been validated; replay rejected.
    /// @param consolidationHash The EIP-712 structHash of the consolidation request
    error ConsolidationAlreadyProcessed(bytes32 consolidationHash);
    /// @notice A top-up referenced a pubkey that has never been initial-deposited by River.
    ///         Without this check, a malicious committee could mark an attacker pubkey as a
    ///         top-up and bypass BLS verification.
    /// @param pubkey The offending 48-byte BLS pubkey
    error TopUpPubkeyNotFunded(bytes pubkey);

    /// @notice recordNewlyFundedPubkeys was passed a pubkey already in the initial-deposit set.
    /// @param pubkey The offending 48-byte BLS pubkey
    error PubkeyAlreadyFunded(bytes pubkey);

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

    /// @notice A pubkey supplied for pre-Pectra removal has not been migrated.
    /// @param pubkey The 48-byte BLS pubkey
    error PrePectraValidatorPubkeyNotFunded(bytes pubkey);

    /// @notice The self consolidation batch is empty.
    error InvalidSelfConsolidationEmptyPubkeys();

    /// @notice A pubkey supplied for self consolidation is not 48 bytes.
    /// @param index The index into the self consolidation batch
    /// @param length The observed pubkey length
    error InvalidSelfConsolidationPubkeyLength(uint256 index, uint256 length);

    // -----------------------------------------------------------------------
    // Initialization
    // -----------------------------------------------------------------------

    /// @notice One-shot initializer for v1 of the AttestationVerifier.
    /// @dev    Configures both the deposit and consolidation attestation flows in a single call.
    ///         Each flow has its own committee, quorum, and EIP-712 domain separator (distinct
    ///         NAME_HASH per flow); they share only the River anchor and the admin lookup.
    ///         Quorum and committee constraints are validated independently per flow. The deposit
    ///         flow uses a pre-commit `DepositDataBuffer` contract; the consolidation flow has no
    ///         on-chain buffer — callers pass `ConsolidationObject` directly into `validateConsolidation`.
    /// @param _river                The River proxy address; used for the EIP-712 verifyingContract
    ///                              binding and for the cross-contract admin lookup.
    /// @param _depositDataBuffer    The pre-commit buffer the keeper writes to.
    /// @param _rootAttesters Initial set of root attester EOAs.
    /// @param _quorum               Initial attestation quorum (1 ≤ quorum ≤ rootAttesters.length).
    /// @param _genesisForkVersion   Genesis fork version used to derive the BLS deposit domain.
    /// @param _consolidationCommitteeAttesters  Initial set of consolidation-committee attester EOAs.
    /// @param _consolidationQuorum              Initial consolidation-attestation quorum
    ///                                          (1 ≤ q ≤ consolidationCommitteeAttesters.length, ≤ MAX_SIGNATURES).
    function initAttestationVerifierV1(
        address _river,
        address _depositDataBuffer,
        address[] calldata _rootAttesters,
        uint256 _quorum,
        bytes4 _genesisForkVersion,
        address[] calldata _consolidationCommitteeAttesters,
        uint256 _consolidationQuorum
    ) external;

    /// @notice Validate and prepare self-consolidation requests for pre-Pectra validator pubkeys.
    ///         Only callable by River.
    /// @dev    For each pubkey: requires membership in the pre-Pectra lookup, then promotes it to
    ///         the post-Pectra lookup (removes the pre-Pectra entry and adds a post-Pectra entry)
    ///         and builds a `src == target` self-consolidation request. The promotion reflects
    ///         the on-chain 0x01→0x02 upgrade so the validator is recognised by downstream
    ///         post-Pectra paths (e.g. top-ups, normal consolidations). The lookup mutations
    ///         atomically revert with the rest of the transaction if the downstream
    ///         consolidation call fails.
    /// @param pubkeys The 48-byte BLS pubkeys to consolidate
    /// @return requests The consolidation requests
    function validateSelfConsolidation(bytes[] calldata pubkeys)
        external
        returns (IWithdrawV1.ConsolidationRequest[] memory);

    // -----------------------------------------------------------------------
    // Validation entry point (called by River)
    // -----------------------------------------------------------------------

    /// @notice Validate attestation quorum + BLS deposit signatures, enforce per-deposit
    ///         withdrawal credentials and total-amount-vs-committed-balance, and return
    ///         the validated batch + total amount for River to execute.
    /// @dev Per-deposit pubkey-state checks fire eagerly inside this call — top-ups must
    ///      reference a pubkey already in the initial-deposit lookup, and initial deposits
    ///      must not duplicate any already-recorded or in-batch pubkey. The buffer's
    ///      `operatorIdx` is NOT verified against any on-chain record (the lookup tracks
    ///      membership only — see PectraValidatorPubkeyLookup natspec). A failure reverts here,
    ///      before River runs any `_depositValidator`.
    /// @dev `depositContract` is supplied by the caller (River) rather than read from the
    ///      verifier's own storage so we avoid an additional cold SLOAD per call. The same
    ///      address is used both for the front-run-resistant `get_deposit_root()` check here
    ///      and for executing `deposit{value:}()` in River, which keeps the attested root and
    ///      the executed-against contract consistent by construction.
    /// @param depositDataBufferId  Batch identifier in the DepositDataBuffer
    /// @param depositRootHash      Current deposit contract root hash co-signed by root attesters
    /// @param signatures           EIP-712 root attester signatures
    /// @param depositContract      The official ETH deposit contract; queried for the current root
    /// @param withdrawalCredentials The protocol-configured WC; every deposit's WC must match
    /// @param committedBalance     Total amount summed over deposits must not exceed this
    /// @return batch               Validated deposit batch (caller executes)
    /// @return totalAmount         Sum of deposit + top-up amounts in the batch
    function validateDeposits(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        address depositContract,
        bytes32 withdrawalCredentials,
        uint256 committedBalance
    ) external view returns (IDepositDataBuffer.DepositObject memory batch, uint256 totalAmount);

    /// @notice Mark a `depositDataBufferId` as processed. Only callable by River.
    /// @dev Called by River after the deposit-execution loop; consulted by `validateDeposits()` to reject replays.
    /// @param depositDataBufferId The batch identifier to mark processed.
    function markDepositDataBufferIdProcessed(bytes32 depositDataBufferId) external;

    // -----------------------------------------------------------------------
    // Initial-deposit recording (called by River after a successful deposit batch)
    // -----------------------------------------------------------------------

    /// @notice Record one or more pubkeys as initial-deposited. Only callable by River.
    /// @dev Called by River after the deposit-execution loop. The recorded set is consulted
    ///      by the top-up branch of `validateDeposits()` to require that top-ups reference a pubkey
    ///      River has previously initial-deposited. Assumes `pubkeys` is already deduplicated
    ///      against the lookup and against itself; `validateDeposits()` enforces both invariants
    ///      earlier in the same transaction. Per-pubkey logging is emitted on the caller
    ///      (ConsensusLayerDepositManager's `PubkeyFunded` event), not here.
    /// @param pubkeys The 48-byte BLS pubkeys to record
    function recordNewlyFundedPubkeys(bytes[] calldata pubkeys) external;

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

    /// @notice Validate consolidation-committee attestations over a `ConsolidationObject` passed
    ///         in by the caller and mark the request as processed for replay protection.
    /// @dev    The caller supplies the full struct (including signatures) in calldata. The
    ///         verifier constructs the EIP-712 typed-data digest directly from the four
    ///         request fields and the cached consolidation domain separator, then recovers
    ///         each signature against that digest. The `signatures` field of the struct is
    ///         NOT part of the typed data.
    ///
    ///         Replay protection: the EIP-712 structHash is recorded in storage on success.
    ///         Subsequent calls with a struct that hashes to the same value revert with
    ///         `ConsolidationAlreadyProcessed`. Note that this makes the function
    ///         state-mutating (not `view`) and callable only by River.
    ///
    ///         The function reverts on any validation failure and returns `true` on success.
    ///         The boolean is a positive signal for off-chain `eth_call` style invocations.
    ///
    ///         Trust boundary: this function only validates structural shape and the attestation
    ///         quorum. The following are intentionally NOT checked here and are delegated to the
    ///         caller (off-chain pipeline / consolidation committee) or to the eventual River
    ///         integration:
    ///           - Source/target pubkey uniqueness (EIP-7251 single-use source rule)
    ///           - `totalAmount` gwei alignment, upper bound, or correlation with pair count
    ///           - Financial caps (e.g. against committed/in-flight balances)
    /// @param consolidation The consolidation request to validate (withdrawal address,
    ///                      source/target pubkeys, totalAmount, signatures).
    /// @return Always `true` if the call returns; reverts otherwise.
    function validateConsolidation(ConsolidationObject calldata consolidation) external returns (bool);

    /// @notice Mark a `depositDataBufferId` as processed. Only callable by River.
    /// @dev Called by River after the deposit-execution loop; consulted by `validateDeposits()` to reject replays.
    /// @param depositDataBufferId The batch identifier to mark processed.
    function markDepositDataBufferIdProcessed(bytes32 depositDataBufferId) external;

    // -----------------------------------------------------------------------
    // Admin setters
    // -----------------------------------------------------------------------

    /// @notice Add or remove a root attester. Only callable by River's admin.
    /// @param rootAttester The root attester address to update
    /// @param value True to register the root attester, false to deregister
    function setRootAttester(address rootAttester, bool value) external;

    /// @notice Update the root attestation quorum. Only callable by River's admin.
    /// @param newQuorum The new quorum (1 ≤ newQuorum ≤ rootAttesterCount, ≤ MAX_SIGNATURES)
    function setRootAttestationQuorum(uint256 newQuorum) external;

    /// @notice Update the DepositDataBuffer address. Only callable by River's admin.
    /// @param _depositDataBuffer The new buffer address
    function setDepositDataBuffer(address _depositDataBuffer) external;

    /// @notice Add or remove a consolidation-committee attester. Only callable by River's admin.
    /// @param consolidationCommitteeAttester The consolidation-committee attester address to update
    /// @param value True to register, false to deregister
    function setConsolidationCommitteeAttester(address consolidationCommitteeAttester, bool value) external;

    /// @notice Update the consolidation-committee attestation quorum. Only callable by River's admin.
    /// @param newQuorum The new quorum (1 ≤ newQuorum ≤ consolidationCommitteeAttesterCount, ≤ MAX_SIGNATURES)
    function setConsolidationCommitteeAttestationQuorum(uint256 newQuorum) external;

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------

    /// @notice Check whether an address is a registered root attester
    /// @param account The address to check
    /// @return True if account is a registered root attester
    function isRootAttester(address account) external view returns (bool);

    /// @notice Retrieve the current number of registered root attesters
    /// @return The root attester count
    function getRootAttesterCount() external view returns (uint256);

    /// @notice Retrieve the current root attestation quorum
    /// @return The required number of valid, unique root attester signatures
    function getRootAttestationQuorum() external view returns (uint256);

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

    // -- Consolidation-side views --

    /// @notice Check whether an address is a registered consolidation-committee attester
    /// @param account The address to check
    /// @return True if account is a registered consolidation-committee attester
    function isConsolidationCommitteeAttester(address account) external view returns (bool);

    /// @notice Retrieve the current number of registered consolidation-committee attesters
    /// @return The consolidation-committee attester count
    function getConsolidationCommitteeAttesterCount() external view returns (uint256);

    /// @notice Retrieve the current consolidation-committee attestation quorum
    /// @return The required number of valid, unique consolidation-committee attester signatures
    function getConsolidationCommitteeAttestationQuorum() external view returns (uint256);

    /// @notice Retrieve the cached EIP-712 consolidation domain separator
    /// @return The EIP-712 consolidation domain separator
    function getConsolidationDomainSeparator() external view returns (bytes32);
    /// @notice Check whether a pubkey has been initial-deposited by River.
    /// @dev Off-chain producers should subscribe to ConsensusLayerDepositManager's `PubkeyFunded`
    ///      events and use this view to confirm a pubkey is eligible for top-up submissions.
    /// @param pubkey The 48-byte BLS pubkey
    /// @return True if the pubkey is currently in the lookup
    function isPubkeyFunded(bytes calldata pubkey) external view returns (bool);

    /// @notice Check whether a pubkey has been migrated from pre-Pectra validator storage.
    /// @dev Intended for consolidation source validation; pre-Pectra keys are not eligible
    ///      top-up targets through `validateDeposits()`.
    /// @param pubkey The 48-byte BLS pubkey
    /// @return True if the pubkey is currently in the pre-Pectra lookup
    function isPrePectraValidatorPubkeyFunded(bytes calldata pubkey) external view returns (bool);

    /// @notice Check whether a `depositDataBufferId` has already been processed.
    /// @param depositDataBufferId The batch identifier
    /// @return True if the ID has already been executed
    function isDepositDataBufferIdProcessed(bytes32 depositDataBufferId) external view returns (bool);
}
