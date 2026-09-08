//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import "../interfaces/IDepositDataBuffer.sol";
import "../interfaces/IDepositContract.sol";
import "../interfaces/IAttestationVerifier.1.sol";

/// @title Deposit Verification
/// @author Alluvial Finance Inc.
/// @notice Provides the functions for initial deposit and top-up verification
abstract contract DepositVerification {
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

    /// @dev EIP-712 typehash of the deposit attestation struct co-signed by the root attesters.
    bytes32 internal constant ATTEST_TYPEHASH =
        keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");

    // -----------------------------------------------------------------------
    // Handlers — implemented by the inheriting contract
    // -----------------------------------------------------------------------

    /// @notice Handler called to apply flow-specific validation to an initial-deposit pubkey
    /// @dev No-op by default; inheriting contracts override it to add their own checks (for example
    ///      the AttestationVerifier's pubkey-lookup membership rules). Must revert to reject.
    /// @param pubkey The 48-byte BLS public key of the initial deposit being validated
    function _customInitialDepositVerification(bytes memory pubkey) internal view virtual {}

    /// @notice Handler called to apply flow-specific validation to a top-up pubkey
    /// @dev No-op by default; inheriting contracts override it to add their own checks (for example
    ///      requiring the pubkey to already be funded). Must revert to reject.
    /// @param pubkey The 48-byte BLS public key of the top-up being validated
    function _customTopUpVerification(bytes memory pubkey) internal view virtual {}

    // -----------------------------------------------------------------------
    // Internal — attestation quorum + deposit/top-up verification
    // -----------------------------------------------------------------------

    /// @notice Verify the attestation quorum.
    /// @dev The quorum, domain separator and attester-set predicate are supplied by the inheriting
    ///      contract so this component stays stateless and reusable across attestation flows.
    /// @param depositDataBufferId The deposit data buffer ID.
    /// @param depositRootHash The deposit root hash.
    /// @param signatures The signatures.
    /// @param depositContract The official ETH deposit contract supplied by River.
    /// @param quorum The required attestation quorum.
    /// @param domainSeparator The EIP-712 domain separator.
    /// @param isRootAttester Predicate telling whether a recovered signer is a registered root attester.
    function _verifyAttestationQuorum(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        address depositContract,
        uint256 quorum,
        bytes32 domainSeparator,
        function(address) internal view returns (bool) isRootAttester
    ) internal view {
        uint256 sigLen = signatures.length;
        if (sigLen > MAX_SIGNATURES) revert IAttestationVerifierV1.TooManySignatures(sigLen, MAX_SIGNATURES);

        if (quorum == 0) revert IAttestationVerifierV1.ZeroQuorum();
        if (sigLen < quorum) revert IAttestationVerifierV1.InsufficientAttestations(sigLen, quorum);

        // Whilst this could be checked earlier in the flow, this way the function is self-contained and performs all the checks required to ensure the attestations are valid in one place.
        bytes32 onChainRoot = IDepositContract(depositContract).get_deposit_root();
        if (onChainRoot != depositRootHash) {
            revert IAttestationVerifierV1.DepositRootMismatch(depositRootHash, onChainRoot);
        }

        if (domainSeparator == bytes32(0)) revert IAttestationVerifierV1.ZeroDomainSeparator();
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, depositDataBufferId, depositRootHash));
        bytes32 digest = ECDSA.toTypedDataHash(domainSeparator, structHash);

        uint256 validCount = 0;
        address[] memory seen = new address[](sigLen);

        for (uint256 i = 0; i < sigLen; i++) {
            address signer = _recover(digest, signatures[i]);
            if (signer == address(0)) continue;
            if (!isRootAttester(signer)) continue;

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

        if (validCount < quorum) revert IAttestationVerifierV1.InsufficientAttestations(validCount, quorum);
    }

    /// @notice Validate every initial deposit in a batch: field lengths, amount bounds and
    ///         gwei-alignment, and per-batch pubkey uniqueness.
    /// @dev Flow-specific pubkey checks are delegated to `_customInitialDepositVerification`, which the
    ///      inheriting contract overrides. Reverts with `InvalidPubkeyLength`, `InvalidSignatureLength`,
    ///      `InvalidDepositAmount` or `PubkeyAlreadyFunded`.
    /// @param deposits The initial deposits to validate.
    /// @param depositCount The number of entries of `deposits` to validate.
    /// @return totalAmount The sum of the validated deposit amounts, in wei.
    function _verifyInitialDeposits(IDepositDataBuffer.StandardDeposit[] memory deposits, uint256 depositCount)
        internal
        view
        returns (uint256 totalAmount)
    {
        bytes32[] memory pubkeyHashes = new bytes32[](depositCount);
        for (uint256 i = 0; i < depositCount; ++i) {
            IDepositDataBuffer.StandardDeposit memory d = deposits[i];
            if (d.pubkey.length != DEPOSIT_PUBKEY_LENGTH) {
                revert IAttestationVerifierV1.InvalidPubkeyLength(i, d.pubkey.length);
            }
            if (d.signature.length != DEPOSIT_SIGNATURE_LENGTH) {
                revert IAttestationVerifierV1.InvalidSignatureLength(i, d.signature.length);
            }
            // Initial deposits must be >= 32 ETH so the validator actually activates on the CL.
            // A sub-32-ETH initial deposit would never activate yet would still inflate
            // InFlightDeposit / _assetBalance() (issue #441/#309). The upper bound and gwei-alignment
            // mirror `_depositValidator`; the 32-ETH floor is stricter here because this loop only
            // covers initial deposits (top-ups are validated separately below and stay >= 1 ETH).
            if (d.amount < MIN_INITIAL_DEPOSIT_AMOUNT || d.amount > MAX_DEPOSIT_AMOUNT || d.amount % 1 gwei != 0) {
                revert IAttestationVerifierV1.InvalidDepositAmount(i, d.amount);
            }
            totalAmount += d.amount;

            _customInitialDepositVerification(d.pubkey);

            bytes32 pkHash = keccak256(d.pubkey);
            pubkeyHashes[i] = pkHash;

            for (uint256 j = 0; j < i; j++) {
                if (pubkeyHashes[j] == pkHash) {
                    revert IAttestationVerifierV1.PubkeyAlreadyFunded(d.pubkey);
                }
            }
        }
    }

    /// @notice Validate every top-up in a batch: pubkey length, amount bounds and gwei-alignment.
    /// @dev Flow-specific pubkey checks are delegated to `_customTopUpVerification`, which the
    ///      inheriting contract overrides. Per-batch duplicate top-up pubkeys are allowed, since each
    ///      top-up credits an already-activated validator. Reverts with `InvalidTopUpPubkeyLength` or
    ///      `InvalidTopUpAmount`.
    /// @param topUps The top-ups to validate.
    /// @param topUpCount The number of entries of `topUps` to validate.
    /// @return totalAmount The sum of the validated top-up amounts, in wei.
    function _verifyTopUps(IDepositDataBuffer.StandardTopUp[] memory topUps, uint256 topUpCount)
        internal
        view
        returns (uint256 totalAmount)
    {
        for (uint256 i = 0; i < topUpCount; ++i) {
            IDepositDataBuffer.StandardTopUp memory t = topUps[i];
            if (t.pubkey.length != DEPOSIT_PUBKEY_LENGTH) {
                revert IAttestationVerifierV1.InvalidTopUpPubkeyLength(i, t.pubkey.length);
            }
            if (t.amount < MIN_TOP_UP_AMOUNT || t.amount > MAX_TOP_UP_AMOUNT || t.amount % 1 gwei != 0) {
                revert IAttestationVerifierV1.InvalidTopUpAmount(i, t.amount);
            }
            totalAmount += t.amount;

            _customTopUpVerification(t.pubkey);
        }
    }

    /// @notice Verify the BLS signatures of all initial deposits against the canonical River
    ///         withdrawal credentials. Top-ups are handled by the caller and never reach this
    ///         function — they're cleared upstream in `fetchAndValidateDeposits()` via the membership check
    ///         on `PectraValidatorPubkeyLookup`.
    /// @param deposits The initial deposits.
    /// @param depositDomain The EIP-712 deposit domain separator.
    function _verifyBLSSignatures(IDepositDataBuffer.StandardDeposit[] memory deposits, bytes32 depositDomain)
        internal
        view
    {
        if (deposits.length == 0) return;
        if (depositDomain == bytes32(0)) revert IAttestationVerifierV1.ZeroDepositDomain();
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
