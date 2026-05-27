//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IDepositDataBuffer.sol";
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
    ///             AttestConsolidation(address user, bytes[] sourcePubkeys, bytes[] targetPubkeys, uint256 totalAmount)
    ///         The `signatures` field itself is NOT part of the typed data — only the four
    ///         request fields are. This is what lets attestors produce signatures over the
    ///         request without a circular dependency.
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
        ///      Not part of the EIP-712 typed data the committee signs.
        bytes[] signatures;
    }

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

    /// @notice The depositYs array length does not match the deposit batch length
    /// @param depositCount The number of deposits in the batch
    /// @param yCount The number of Y-coordinates supplied
    error BLSSignatureCountMismatch(uint256 depositCount, uint256 yCount);

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

    /// @notice The consolidation's totalAmount is zero
    error ZeroConsolidationTotalAmount();

    /// @notice The consolidation's user is the zero address
    error ZeroConsolidationUser();

    /// @notice The supplied quorum is greater than the current consolidation-committee attester count
    /// @param quorum The supplied quorum
    /// @param consolidationCommitteeAttesterCount The current consolidation-committee attester count
    error QuorumExceedsConsolidationCommitteeAttesterCount(uint256 quorum, uint256 consolidationCommitteeAttesterCount);

    /// @notice Adding a consolidation-committee attester would exceed MAX_CONSOLIDATION_COMMITTEE_ATTESTERS
    /// @param count The would-be consolidation-committee attester count
    /// @param max The MAX_CONSOLIDATION_COMMITTEE_ATTESTERS bound
    error TooManyConsolidationCommitteeAttesters(uint256 count, uint256 max);

    /// @notice setConsolidationCommitteeAttester was called with the attester already in the requested state
    /// @param consolidationCommitteeAttester The consolidation-committee attester address
    /// @param value The requested status (matches current status)
    error ConsolidationCommitteeAttesterStatusUnchanged(address consolidationCommitteeAttester, bool value);

    /// @notice The supplied consolidation has already been validated; replay rejected.
    /// @param consolidationHash The EIP-712 structHash of the consolidation request
    error ConsolidationAlreadyProcessed(bytes32 consolidationHash);

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
    /// @param _river                            The River proxy address; used for both
    ///                                          EIP-712 domain separators and for the cross-
    ///                                          contract admin lookup.
    /// @param _depositDataBuffer                The pre-commit deposit buffer the keeper writes to.
    /// @param _depositCommitteeAttesters        Initial set of deposit-committee attester EOAs.
    /// @param _depositQuorum                    Initial deposit-attestation quorum
    ///                                          (1 ≤ q ≤ depositCommitteeAttesters.length, ≤ MAX_SIGNATURES).
    /// @param _genesisForkVersion               Genesis fork version used to derive the BLS deposit domain.
    /// @param _consolidationCommitteeAttesters  Initial set of consolidation-committee attester EOAs.
    /// @param _consolidationQuorum              Initial consolidation-attestation quorum
    ///                                          (1 ≤ q ≤ consolidationCommitteeAttesters.length, ≤ MAX_SIGNATURES).
    function initAttestationVerifierV1(
        address _river,
        address _depositDataBuffer,
        address[] calldata _depositCommitteeAttesters,
        uint256 _depositQuorum,
        bytes4 _genesisForkVersion,
        address[] calldata _consolidationCommitteeAttesters,
        uint256 _consolidationQuorum
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
    /// @param depositYs            Y-coordinates for BLS decompression, one per deposit
    /// @param depositContract      The official ETH deposit contract; queried for the current root
    /// @param withdrawalCredentials The protocol-configured WC; every deposit's WC must match
    /// @param committedBalance     Total amount summed over deposits must not exceed this
    /// @return deposits            Validated deposit batch (caller executes)
    /// @return totalAmount         Sum of deposit amounts in the batch
    function validateDeposits(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        BLS12_381.DepositY[] calldata depositYs,
        address depositContract,
        bytes32 withdrawalCredentials,
        uint256 committedBalance
    ) external view returns (IDepositDataBuffer.DepositObject[] memory deposits, uint256 totalAmount);

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
    ///         state-mutating (not `view`). NOTE: the function is permissionless; if a
    ///         malicious caller front-runs the legitimate consumer they can mark a request
    ///         as processed and DoS subsequent legitimate validation. Caller-restriction is
    ///         out of scope for this PR; it lives in the eventual River integration (which
    ///         can either gate the verifier or atomically combine validation with its own
    ///         downstream action).
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
    /// @param consolidation The consolidation request to validate (user, source/target pubkeys,
    ///                      totalAmount, signatures).
    /// @return Always `true` if the call returns; reverts otherwise.
    function validateConsolidation(ConsolidationObject calldata consolidation) external returns (bool);

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
}
