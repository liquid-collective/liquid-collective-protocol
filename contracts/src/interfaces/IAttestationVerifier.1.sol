//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IConsolidationDataBuffer.sol";
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

    /// @notice Emitted when the ConsolidationDataBuffer address is updated
    event SetConsolidationDataBuffer(address indexed consolidationDataBuffer);

    /// @notice Emitted when a consolidation-committee attester is added or removed
    event SetConsolidationCommitteeAttester(address indexed consolidationCommitteeAttester, bool value);

    /// @notice Emitted when the consolidation-committee attestation quorum is updated
    event SetConsolidationCommitteeAttestationQuorum(uint256 quorum);

    /// @notice Emitted when the EIP-712 consolidation domain separator is (re)cached
    event SetConsolidationDomainSeparator(bytes32 consolidationDomainSeparator);

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

    /// @notice The ConsolidationDataBuffer returned a consolidation with zero source pubkeys
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

    /// @notice The recomputed consolidation bufferId does not match the attested bufferId
    /// @param expected The bufferId co-signed by consolidation-committee attesters
    /// @param actual The bufferId recomputed from the buffer's returned content
    error ConsolidationBufferIdMismatch(bytes32 expected, bytes32 actual);

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

    /// @notice One-shot initializer for the consolidation-attestation extension.
    /// @dev    Must be called after `initAttestationVerifierV1`. Uses `init(1)` so the River
    ///         address and admin lookup configured by the v1 init are reused unchanged.
    /// @param _consolidationDataBuffer    The pre-commit consolidation buffer the keeper reads from.
    /// @param _consolidationCommitteeAttesters Initial set of consolidation-committee attester EOAs.
    /// @param _quorum                     Initial consolidation-attestation quorum
    ///                                    (1 ≤ quorum ≤ consolidationCommitteeAttesters.length).
    function initAttestationVerifierV1_1(
        address _consolidationDataBuffer,
        address[] calldata _consolidationCommitteeAttesters,
        uint256 _quorum
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
    function validate(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        BLS12_381.DepositY[] calldata depositYs,
        address depositContract,
        bytes32 withdrawalCredentials,
        uint256 committedBalance
    ) external view returns (IDepositDataBuffer.DepositObject[] memory deposits, uint256 totalAmount);

    /// @notice Validate consolidation-committee attestations over a buffered consolidation request
    ///         and return the trusted struct + totalAmount for the caller to act on.
    /// @dev    Signatures are read from the buffer's `ConsolidationObject.signatures` field, not
    ///         supplied as calldata. The bufferId binding excludes signatures so signers can sign
    ///         the bufferId without a circular dependency. This function does NOT enforce any
    ///         financial cap — that lives in the eventual River integration.
    /// @param consolidationDataBufferId The bufferId co-signed by consolidation-committee attesters
    /// @return consolidation            The validated consolidation object
    /// @return totalAmount              Sum of the consolidation's totalAmount (mirrored from struct)
    function validateConsolidation(bytes32 consolidationDataBufferId)
        external
        view
        returns (IConsolidationDataBuffer.ConsolidationObject memory consolidation, uint256 totalAmount);

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

    /// @notice Update the ConsolidationDataBuffer address. Only callable by River's admin.
    /// @param _consolidationDataBuffer The new buffer address
    function setConsolidationDataBuffer(address _consolidationDataBuffer) external;

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

    /// @notice Retrieve the configured ConsolidationDataBuffer address
    /// @return The ConsolidationDataBuffer address
    function getConsolidationDataBuffer() external view returns (address);

    /// @notice Retrieve the cached EIP-712 consolidation domain separator
    /// @return The EIP-712 consolidation domain separator
    function getConsolidationDomainSeparator() external view returns (bytes32);
}
