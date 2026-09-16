//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Deposit Verification Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice Error surface of the `DepositVerification` component, which provides the shared
///         attestation-quorum, initial-deposit and top-up verification used by both the
///         AttestationVerifier deposit flow and the DepositDataBuffer submission path.
/// @dev Declares errors only — `DepositVerification` exposes no external functions of its own; every
///      entry point is internal and reached through the inheriting contract.
interface IDepositVerification {
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

    /// @notice The submitted signatures array exceeds MAX_SIGNATURES
    /// @param count The submitted signature count
    /// @param max The configured maximum
    error TooManySignatures(uint256 count, uint256 max);

    /// @notice An initial deposit's pubkey field has an unexpected byte length
    /// @param index Index into `batch.deposits`
    /// @param length The observed length
    error InvalidPubkeyLength(uint256 index, uint256 length);

    /// @notice A top-up's pubkey field has an unexpected byte length
    /// @param index Index into `batch.topUps`
    /// @param length The observed length
    error InvalidTopUpPubkeyLength(uint256 index, uint256 length);

    /// @notice A deposit's BLS signature field has an unexpected byte length
    /// @dev Only raised while iterating `batch.deposits` — top-ups have no signature field.
    /// @param index Index into `batch.deposits`
    /// @param length The observed length
    error InvalidSignatureLength(uint256 index, uint256 length);

    /// @notice An initial deposit's `amount` is outside the protocol-accepted range
    ///         [MIN_INITIAL_DEPOSIT_AMOUNT (32 ether), 2048 ether] or is not gwei-aligned. Initial
    ///         deposits require the full 32 ether so the validator actually activates on the consensus
    ///         layer; a smaller amount would never activate yet would still inflate InFlightDeposit /
    ///         `_assetBalance()` (see #441). This 32 ether floor is intentionally distinct from the
    ///         top-up range, which allows down to 1 ether (see `InvalidTopUpAmount`) because top-ups
    ///         credit already-activated validators. Enforced here in `fetchAndValidateDeposits()` so
    ///         producer bugs fail before the heavy BLS path runs; downstream `_depositValidator`
    ///         trusts this check.
    /// @param index Index into `batch.deposits`
    /// @param amount The offending amount in wei
    error InvalidDepositAmount(uint256 index, uint256 amount);

    /// @notice A top-up's `amount` is outside the protocol-accepted range
    ///         [1 ether, 2016 ether] or is not gwei-aligned. Top-ups credit already-activated
    ///         validators, so the lower bound is 1 ether — intentionally below the 32 ether floor
    ///         that initial deposits require (see `InvalidDepositAmount`). The 2016 ether upper bound
    ///         is the stateless headroom from a 32 ether funded validator to the 2048 ether Pectra max
    ///         effective balance. Enforced here in `fetchAndValidateDeposits()` so producer bugs fail
    ///         before the heavy BLS path runs; downstream `_depositValidator` trusts this check.
    /// @param index Index into `batch.topUps`
    /// @param amount The offending amount in wei
    error InvalidTopUpAmount(uint256 index, uint256 amount);

    /// @notice An attestation quorum of zero was supplied
    error ZeroQuorum();

    /// @notice The EIP-712 domain separator has not been initialized
    error ZeroDomainSeparator();

    /// @notice The BLS deposit domain has not been initialized
    error ZeroDepositDomain();

    /// @notice recordNewlyFundedPubkeys was passed a pubkey already in the initial-deposit set.
    /// @param pubkey The offending 48-byte BLS pubkey
    error PubkeyAlreadyFunded(bytes pubkey);
}
