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

    /// @notice Emitted when the deposit contract address is updated
    event SetDepositContract(address indexed depositContract);

    /// @notice Emitted when an attester is added or removed
    event SetAttester(address indexed attester, bool value);

    /// @notice Emitted when the attestation quorum is updated
    event SetAttestationQuorum(uint256 quorum);

    /// @notice Emitted when the EIP-712 domain separator is (re)cached
    event SetDomainSeparator(bytes32 domainSeparator);

    /// @notice Emitted when the BLS deposit domain is set
    event SetDepositDomain(bytes32 depositDomain);

    /// @notice Emitted when the River address is set on this verifier
    event SetRiver(address indexed river);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error InsufficientAttestations(uint256 valid, uint256 quorum);
    error NoDeposits();
    error DepositRootMismatch(bytes32 expected, bytes32 actual);
    error BufferIdMismatch(bytes32 expected, bytes32 actual);
    error TooManySignatures(uint256 count, uint256 max);
    error BLSSignatureCountMismatch(uint256 depositCount, uint256 yCount);
    error InvalidWithdrawalCredentialsLength(uint256 index, uint256 length);
    error InvalidPubkeyLength(uint256 index, uint256 length);
    error InvalidSignatureLength(uint256 index, uint256 length);
    error WithdrawalCredentialsMismatch(uint256 depositIndex, bytes32 expected, bytes32 actual);
    error NotEnoughFunds();
    error ZeroQuorum();
    error ZeroDomainSeparator();
    error ZeroDepositDomain();
    error QuorumExceedsAttesterCount(uint256 quorum, uint256 attesterCount);
    error QuorumExceedsMaxSignatures(uint256 quorum, uint256 max);
    error TooManyAttesters(uint256 count, uint256 max);
    error AttesterStatusUnchanged(address attester, bool value);

    // -----------------------------------------------------------------------
    // Initialization
    // -----------------------------------------------------------------------

    /// @notice One-shot initializer for v1 of the AttestationVerifier.
    /// @param _river                The River proxy address; used for the EIP-712 verifyingContract
    ///                              binding and for the cross-contract admin lookup.
    /// @param _depositContract      The official ETH deposit contract.
    /// @param _depositDataBuffer    The pre-commit buffer the keeper writes to.
    /// @param _attesters            Initial set of attester EOAs.
    /// @param _quorum               Initial attestation quorum (1 ≤ quorum ≤ attesters.length).
    /// @param _genesisForkVersion   Genesis fork version used to derive the BLS deposit domain.
    function initAttestationVerifierV1(
        address _river,
        address _depositContract,
        address _depositDataBuffer,
        address[] calldata _attesters,
        uint256 _quorum,
        bytes4 _genesisForkVersion
    ) external;

    // -----------------------------------------------------------------------
    // Validation entry point (called by River)
    // -----------------------------------------------------------------------

    /// @notice Validate attestation quorum + BLS deposit signatures, enforce per-deposit
    ///         withdrawal credentials and total-amount-vs-committed-balance, and return
    ///         the validated batch + total amount for River to execute.
    /// @param depositDataBufferId  Batch identifier in the DepositDataBuffer
    /// @param depositRootHash      Current deposit contract root hash co-signed by attesters
    /// @param signatures           EIP-712 attester signatures
    /// @param depositYs            Y-coordinates for BLS decompression, one per deposit
    /// @param withdrawalCredentials The protocol-configured WC; every deposit's WC must match
    /// @param committedBalance     Total amount summed over deposits must not exceed this
    /// @return deposits            Validated deposit batch (caller executes)
    /// @return totalAmount         Sum of deposit amounts in the batch
    function validateAndPrepare(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        BLS12_381.DepositY[] calldata depositYs,
        bytes32 withdrawalCredentials,
        uint256 committedBalance
    ) external view returns (IDepositDataBuffer.DepositObject[] memory deposits, uint256 totalAmount);

    // -----------------------------------------------------------------------
    // Admin setters
    // -----------------------------------------------------------------------

    function setAttester(address attester, bool value) external;
    function setAttestationQuorum(uint256 newQuorum) external;
    function setDepositDataBuffer(address _depositDataBuffer) external;
    function setDepositContract(address _depositContract) external;

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------

    function isAttester(address account) external view returns (bool);
    function getAttesterCount() external view returns (uint256);
    function getAttestationQuorum() external view returns (uint256);
    function getDepositDataBuffer() external view returns (address);
    function getDepositContract() external view returns (address);
    function getDomainSeparator() external view returns (bytes32);
    /// @notice The BLS deposit domain.
    /// @dev Capitalized for backwards compatibility with prior public API
    /// solhint-disable-next-line func-name-mixedcase
    function DEPOSIT_DOMAIN() external view returns (bytes32);
    /// @notice The River address this verifier is bound to (verifyingContract + admin source)
    function getRiver() external view returns (address);
}
