//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import "../interfaces/IDepositDataBuffer.sol";
import "../interfaces/IDepositContract.sol";
import "../interfaces/IAttestationVerifier.1.sol";

// ToDo: make it state agnostic
import "../state/attestationVerifier/PectraValidatorPubkeyLookup.sol";
import "../state/attestationVerifier/PrePectraValidatorPubkeyLookup.sol";
import "../state/attestationVerifier/RootAttesters.sol";
import "../state/attestationVerifier/DomainSeparator.sol";
import "../state/attestationVerifier/DepositDomainValue.sol";

import "../AttestationVerifier.1.sol";

/// @title Lib Deposit Verification
/// @author Alluvial Finance Inc.
/// @notice This library provides functions for deposit verification
library LibDepositVerification {
    /// @notice Minimum amount for an initial validator deposit. A brand-new validator requires the
    ///         full 32 ETH to activate on the consensus layer; a smaller initial deposit would never
    ///         activate yet would still be counted in InFlightDeposit / TotalDepositedETH, permanently
    ///         inflating River's `_assetBalance()` (issue #441/#309). Top-ups are intentionally exempt —
    ///         they credit already-activated validators and may be below this amount.
    uint256 internal constant MIN_INITIAL_DEPOSIT_AMOUNT = 32 ether;

    /// @notice Minimum top-up amount accepted by the consensus-layer deposit path.
    uint256 internal constant MIN_TOP_UP_AMOUNT = 1 ether;

    /// @notice Maximum deposit amount — the Pectra 0x02 maximum effective balance.
    uint256 internal constant MAX_DEPOSIT_AMOUNT = 2048 ether;

    /// @notice Maximum stateless top-up: a funded validator should already have at least 32 ETH.
    uint256 internal constant MAX_TOP_UP_AMOUNT = MAX_DEPOSIT_AMOUNT - MIN_INITIAL_DEPOSIT_AMOUNT;

    /// @dev Expected lengths for fixed BLS-related fields in a DepositObject.
    uint256 internal constant DEPOSIT_PUBKEY_LENGTH = 48;
    uint256 internal constant DEPOSIT_SIGNATURE_LENGTH = 96;

    /// @notice Maximum number of signatures accepted. Bounds the O(n^2) duplicate-detection loop.
    uint256 public constant MAX_SIGNATURES = 20;

    bytes32 internal constant ATTEST_TYPEHASH =
        keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");

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

    /// @notice A top-up's pubkey field has an unexpected byte length
    /// @param index Index into `batch.topUps`
    /// @param length The observed length
    error InvalidTopUpPubkeyLength(uint256 index, uint256 length);

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

    /// @notice An initial deposit's pubkey field has an unexpected byte length
    /// @param index Index into `batch.deposits`
    /// @param length The observed length
    error InvalidPubkeyLength(uint256 index, uint256 length);

    /// @notice A deposit's BLS signature field has an unexpected byte length
    /// @dev Only raised while iterating `batch.deposits` — top-ups have no signature field.
    /// @param index Index into `batch.deposits`
    /// @param length The observed length
    error InvalidSignatureLength(uint256 index, uint256 length);

    /// @notice A batch referenced a pubkey still in the pre-Pectra lookup as if it were a
    ///         Pectra validator. Migrated legacy keys must first be promoted via
    ///         self-consolidation before they can be initial-deposited or topped up.
    /// @param pubkey The offending 48-byte BLS pubkey
    error PrePectraValidatorPubkeyNotConsolidated(bytes pubkey);

    /// @notice recordNewlyFundedPubkeys was passed a pubkey already in the initial-deposit set.
    /// @param pubkey The offending 48-byte BLS pubkey
    error PubkeyAlreadyFunded(bytes pubkey);

    /// @notice A top-up referenced a pubkey that has never been initial-deposited by River.
    ///         Without this check, a malicious committee could mark an attacker pubkey as a
    ///         top-up and bypass BLS verification.
    /// @param pubkey The offending 48-byte BLS pubkey
    error TopUpPubkeyNotFunded(bytes pubkey);

    /// @notice The submitted signatures array exceeds MAX_SIGNATURES
    /// @param count The submitted signature count
    /// @param max The configured maximum
    error TooManySignatures(uint256 count, uint256 max);

    /// @notice The number of valid, unique root attester signatures is below the configured quorum
    /// @param valid The count of valid, unique root attester signatures recovered
    /// @param quorum The required quorum
    error InsufficientAttestations(uint256 valid, uint256 quorum);

    /// @notice The co-signed deposit root does not match the deposit contract's current root
    /// @param expected The deposit root co-signed by root attesters
    /// @param actual The current root reported by the deposit contract
    error DepositRootMismatch(bytes32 expected, bytes32 actual);

    /// @notice The EIP-712 domain separator has not been initialized
    error ZeroDomainSeparator();

    /// @notice An attestation quorum of zero was supplied
    error ZeroQuorum();

    /// @notice An external caller invoked a function reserved for self-staticcall trampolining.
    error OnlySelfCall();

    /// @notice The BLS deposit domain has not been initialized
    error ZeroDepositDomain();

    /// @notice Verify the attestation quorum.
    /// @param depositDataBufferId The deposit data buffer ID.
    /// @param depositRootHash The deposit root hash.
    /// @param signatures The signatures.
    /// @param depositContract The official ETH deposit contract supplied by River.
    /// @param quorum The required attestation quorum.
    function _verifyAttestationQuorum(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        address depositContract,
        uint256 quorum
    ) internal view {
        uint256 sigLen = signatures.length;
        if (sigLen > MAX_SIGNATURES) revert TooManySignatures(sigLen, MAX_SIGNATURES);

        if (quorum == 0) revert ZeroQuorum();
        if (sigLen < quorum) revert InsufficientAttestations(sigLen, quorum);

        // Whilst this could be checked earlier in the flow, this way the function is self-contained and performs all the checks required to ensure the attestations are valid in one place.
        bytes32 onChainRoot = IDepositContract(depositContract).get_deposit_root();
        if (onChainRoot != depositRootHash) revert DepositRootMismatch(depositRootHash, onChainRoot);

        bytes32 domainSep = DomainSeparator.get();
        if (domainSep == bytes32(0)) revert ZeroDomainSeparator();
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, depositDataBufferId, depositRootHash));
        bytes32 digest = ECDSA.toTypedDataHash(domainSep, structHash);

        uint256 validCount = 0;
        address[] memory seen = new address[](sigLen);

        for (uint256 i = 0; i < sigLen; i++) {
            address signer = _recover(digest, signatures[i]);
            if (signer == address(0)) continue;
            if (!RootAttesters.isRootAttester(signer)) continue;

            bool duplicate = false;
            for (uint256 j = 0; j < validCount; j++) {
                if (seen[j] == signer) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) continue;

            seen[validCount] = signer;
            validCount++;
        }

        if (validCount < quorum) revert InsufficientAttestations(validCount, quorum);
    }

    function _verifyInitialDeposits(IDepositDataBuffer.StandardDeposit[] memory deposits, uint256 depositCount)
        internal
        view
        returns (uint256 totalAmount)
    {
        bytes32[] memory pubkeyHashes = new bytes32[](depositCount);
        for (uint256 i = 0; i < depositCount; ++i) {
            IDepositDataBuffer.StandardDeposit memory d = deposits[i];
            if (d.pubkey.length != DEPOSIT_PUBKEY_LENGTH) {
                revert InvalidPubkeyLength(i, d.pubkey.length);
            }
            if (d.signature.length != DEPOSIT_SIGNATURE_LENGTH) {
                revert InvalidSignatureLength(i, d.signature.length);
            }
            // Initial deposits must be >= 32 ETH so the validator actually activates on the CL.
            // A sub-32-ETH initial deposit would never activate yet would still inflate
            // InFlightDeposit / _assetBalance() (issue #441/#309). The upper bound and gwei-alignment
            // mirror `_depositValidator`; the 32-ETH floor is stricter here because this loop only
            // covers initial deposits (top-ups are validated separately below and stay >= 1 ETH).
            if (d.amount < MIN_INITIAL_DEPOSIT_AMOUNT || d.amount > MAX_DEPOSIT_AMOUNT || d.amount % 1 gwei != 0) {
                revert InvalidDepositAmount(i, d.amount);
            }
            totalAmount += d.amount;

            bytes32 pkHash = keccak256(d.pubkey);
            pubkeyHashes[i] = pkHash;

            if (PectraValidatorPubkeyLookup.isPubkeyFunded(d.pubkey)) {
                revert PubkeyAlreadyFunded(d.pubkey);
            }
            // A migrated pre-Pectra (0x01) key must be promoted via self-consolidation, not
            // reintroduced as a fresh initial deposit. Gating here keeps the pre-Pectra lookup
            // authoritative and preserves the migration state machine even if a producer or
            // attester batch is malformed.
            if (PrePectraValidatorPubkeyLookup.isPubkeyFunded(d.pubkey)) {
                revert PrePectraValidatorPubkeyNotConsolidated(d.pubkey);
            }
            for (uint256 j = 0; j < i; j++) {
                if (pubkeyHashes[j] == pkHash) {
                    revert PubkeyAlreadyFunded(d.pubkey);
                }
            }
        }
    }

    function _verifyTopUps(IDepositDataBuffer.StandardTopUp[] memory topUps, uint256 topUpCount)
        internal
        view
        returns (uint256 totalAmount)
    {
        for (uint256 i = 0; i < topUpCount; ++i) {
            IDepositDataBuffer.StandardTopUp memory t = topUps[i];
            if (t.pubkey.length != DEPOSIT_PUBKEY_LENGTH) {
                revert InvalidTopUpPubkeyLength(i, t.pubkey.length);
            }
            if (t.amount < MIN_TOP_UP_AMOUNT || t.amount > MAX_TOP_UP_AMOUNT || t.amount % 1 gwei != 0) {
                revert InvalidTopUpAmount(i, t.amount);
            }
            totalAmount += t.amount;

            // Explicitly reject migrated pre-Pectra keys with a distinct error. Such a key is not
            // in the Pectra lookup so it would otherwise revert as TopUpPubkeyNotFunded; the
            // dedicated error tells producers the key must be self-consolidated first.
            if (PrePectraValidatorPubkeyLookup.isPubkeyFunded(t.pubkey)) {
                revert PrePectraValidatorPubkeyNotConsolidated(t.pubkey);
            }
            if (!PectraValidatorPubkeyLookup.isPubkeyFunded(t.pubkey)) {
                revert TopUpPubkeyNotFunded(t.pubkey);
            }
        }
    }

    /// @notice Verify the BLS signatures of all initial deposits against the canonical River
    ///         withdrawal credentials. Top-ups are handled by the caller and never reach this
    ///         function — they're cleared upstream in `fetchAndValidateDeposits()` via the membership check
    ///         on `PectraValidatorPubkeyLookup`.
    /// @param deposits The initial deposits.
    /// @param withdrawalCredentials The canonical River withdrawal credentials.
    function _verifyBLSSignatures(IDepositDataBuffer.StandardDeposit[] memory deposits, bytes32 withdrawalCredentials)
        internal
        view
    {
        if (deposits.length == 0) return;
        bytes32 depositDomain = DepositDomainValue.get();
        if (depositDomain == bytes32(0)) revert ZeroDepositDomain();
        for (uint256 i = 0; i < deposits.length; i++) {
            BLS12_381.verifyDepositMessage(
                deposits[i].pubkey,
                deposits[i].signature,
                deposits[i].amount,
                deposits[i].depositY,
                deposits[i].withdrawalCredentials,
                depositDomain
            );
        }
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// @dev Recover signer from a 65-byte EIP-712 signature, normalizing v.
    /// @param digest The digest.
    /// @param sig The signature.
    /// @return The recovered signer.
    function _recover(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        if (sig.length != 65) return address(0);

        uint8 v = uint8(sig[64]);
        if (v < 27) v += 27;
        if (v != 27 && v != 28) return address(0);

        bytes32 r;
        bytes32 s;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 0x20))
        }

        (address recovered, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, v, r, s);
        if (err != ECDSA.RecoverError.NoError) return address(0);
        return recovered;
    }
}
