// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IDepositDataBuffer} from "../interfaces/IDepositDataBuffer.sol";
import {IDepositContract} from "../interfaces/IDepositContract.sol";
import {BLS12_381} from "../libraries/BLS12_381.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {DomainSeparator} from "../state/river/DomainSeparator.sol";

/// @title DepositToConsensusLayerValidation
/// @notice Abstract contract that validates attestation quorum signatures and BLS deposit data.
///         Storage hooks (_isAttester, _depositCommitteeQuorum) are virtual so that proxy-based deployments
///         (River) can override them with unstructured storage.
abstract contract DepositToConsensusLayerValidation {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    /// @notice Insufficient attestations
    /// @param valid The number of valid attestations
    /// @param quorum The quorum required
    error InsufficientAttestations(uint256 valid, uint256 quorum);

    /// @notice No deposits
    error NoDeposits();

    /// @notice Deposit root mismatch
    /// @param expected The expected deposit root
    /// @param actual The actual deposit root
    error DepositRootMismatch(bytes32 expected, bytes32 actual);

    /// @notice Buffer ID mismatch
    /// @param expected The expected buffer ID
    /// @param actual The actual buffer ID
    error BufferIdMismatch(bytes32 expected, bytes32 actual);

    /// @notice Too many signatures
    /// @param count The number of signatures
    /// @param max The maximum number of signatures allowed
    error TooManySignatures(uint256 count, uint256 max);

    /// @notice BLS signature count mismatch
    /// @param depositCount The number of deposits
    /// @param yCount The number of Y-coordinates
    error BLSSignatureCountMismatch(uint256 depositCount, uint256 yCount);

    /// @notice Invalid pubkey length
    /// @param index The index of the pubkey
    /// @param length The length of the pubkey
    error InvalidPubkeyLength(uint256 index, uint256 length);

    /// @notice Invalid signature length
    /// @param index The index of the signature
    /// @param length The length of the signature
    error InvalidSignatureLength(uint256 index, uint256 length);

    /// @notice Zero quorum
    error ZeroQuorum();

    /// @notice Zero domain separator
    error ZeroDomainSeparator();

    /// @notice Zero deposit domain
    error ZeroDepositDomain();

    /// @notice Quorum exceeds attester count
    /// @param quorum The quorum
    /// @param attesterCount The number of attesters
    error QuorumExceedsAttesterCount(uint256 quorum, uint256 attesterCount);

    /// @notice Quorum exceeds max signatures
    /// @param quorum The quorum
    /// @param max The maximum number of signatures allowed
    error QuorumExceedsMaxSignatures(uint256 quorum, uint256 max);

    /// @notice Too many attesters
    /// @param count The number of attesters
    /// @param max The maximum number of attesters allowed
    error TooManyAttesters(uint256 count, uint256 max);

    /// @notice Zero address
    error ZeroAddress();

    /// @notice Attester status unchanged
    /// @param attester The attester
    /// @param status The new status
    error AttesterStatusUnchanged(address attester, bool status);

    // -----------------------------------------------------------------------
    // EIP-712
    // -----------------------------------------------------------------------

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("DepositToConsensusLayerValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");

    bytes32 internal constant ATTEST_TYPEHASH =
        keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");

    /// @notice Maximum number of signatures accepted. Bounds the O(n^2) duplicate-detection loop.
    uint256 public constant MAX_SIGNATURES = 20;

    /// @notice Maximum number of registered attesters. Defensive cap to bound storage growth.
    uint256 public constant MAX_ATTESTERS = 32;

    /// @dev Expected lengths for fixed BLS-related fields in a DepositObject.
    uint256 internal constant DEPOSIT_PUBKEY_LENGTH = 48;
    uint256 internal constant DEPOSIT_SIGNATURE_LENGTH = 96;

    // -----------------------------------------------------------------------
    // Virtual storage hooks — override in proxy-based deployments
    // -----------------------------------------------------------------------

    /// @notice Check if an account is an attester
    /// @param account The account to check
    /// @return True if the account is an attester, false otherwise
    function _isAttester(address account) internal view virtual returns (bool);

    /// @notice Set the attester status for an account
    /// @param account The account to set
    /// @param value The new attester status
    function _setAttester(address account, bool value) internal virtual;

    /// @notice Retrieve the attestation quorum
    /// @return The attestation quorum
    function _depositCommitteeQuorum() internal view virtual returns (uint256);

    /// @notice Set the attestation quorum
    /// @param value The new attestation quorum
    function _setDepositCommitteeQuorum(uint256 value) internal virtual;

    /// @notice Retrieve the domain separator
    /// @return The domain separator
    function _domainSeparator() internal view virtual returns (bytes32) {
        return DomainSeparator.get();
    }

    /// @dev Override in proxy deployments to read the deposit data buffer from unstructured storage.
    /// @return The deposit data buffer
    function _depositDataBuffer() internal view virtual returns (IDepositDataBuffer);

    /// @dev Override in proxy deployments to read the deposit contract from unstructured storage.
    /// @return The deposit contract
    function _depositContract() internal view virtual returns (IDepositContract);

    /// @dev Override to return the BLS deposit domain for the target chain.
    ///      In River proxy deployments, reads from DepositDomainValue unstructured storage.
    ///      In standalone deployments, may return a hardcoded value or a stored immutable.
    /// @return The deposit domain
    function _depositDomain() internal view virtual returns (bytes32);

    // -----------------------------------------------------------------------
    // Public view getters (delegate to virtual hooks)
    // -----------------------------------------------------------------------

    /// @notice Check if an account is an attester
    /// @param a The account to check
    /// @return True if the account is an attester, false otherwise
    function isAttester(address a) public view returns (bool) {
        return _isAttester(a);
    }

    /// @notice Retrieve the attestation quorum
    /// @return The attestation quorum
    function depositCommitteeQuorum() public view returns (uint256) {
        return _depositCommitteeQuorum();
    }

    /// @notice Retrieve the deposit domain
    /// @return The deposit domain
    function DEPOSIT_DOMAIN() public view returns (bytes32) {
        return _depositDomain();
    }

    // -----------------------------------------------------------------------
    // Validate — pure attestation+BLS validation, no ETH effects
    // -----------------------------------------------------------------------

    /// @notice Validate attestation signatures and BLS deposit data.
    ///         Returns the validated deposits array for use by the caller.
    /// @param depositDataBufferId   Batch identifier in the DepositDataBuffer
    /// @param depositRootHash       Current deposit contract root hash co-signed by attesters
    /// @param signatures            EIP-712 signatures from attesters
    /// @param depositYs             Y-coordinates for BLS decompression, one per deposit
    /// @param withdrawalCredentials Canonical River withdrawal credentials. Used for BLS
    ///                              signature verification, removing any need to trust the
    ///                              buffer producer on this field.
    /// @return deposits             The validated deposit batch
    function validate(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        BLS12_381.DepositY[] calldata depositYs,
        bytes32 withdrawalCredentials
    ) public view returns (IDepositDataBuffer.DepositObject[] memory deposits) {
        // 1. Verify attestation quorum
        _verifyAttestationQuorum(depositDataBufferId, depositRootHash, signatures);

        // 2. Get deposit data from buffer
        deposits = _depositDataBuffer().getDepositData(depositDataBufferId);
        uint256 depositCount = deposits.length;
        if (depositCount == 0) revert NoDeposits();

        // 3. Verify the buffer returned deposits that hash back to the signed bufferId.
        //    This removes the DepositDataBuffer contract from the attestation trust chain:
        //    attesters sign the keccak256 commitment, and we enforce here that the deposits we
        //    are about to execute are exactly the ones that commitment covers.
        bytes32 computedId = keccak256(abi.encode(deposits));
        if (computedId != depositDataBufferId) {
            revert BufferIdMismatch(depositDataBufferId, computedId);
        }

        // 4. Check depositYs count
        if (depositYs.length != depositCount) {
            revert BLSSignatureCountMismatch(depositCount, depositYs.length);
        }

        // 5. Enforce fixed lengths on dynamic-bytes fields. Without this, a buffer producer
        //    can pad fields beyond their canonical length; the keccak commitment binds whatever
        //    encoding was submitted, but the BLS lib would silently ignore trailing bytes and
        //    create encoding ambiguity.
        for (uint256 i = 0; i < depositCount; i++) {
            if (deposits[i].pubkey.length != DEPOSIT_PUBKEY_LENGTH) {
                revert InvalidPubkeyLength(i, deposits[i].pubkey.length);
            }
            if (deposits[i].signature.length != DEPOSIT_SIGNATURE_LENGTH) {
                revert InvalidSignatureLength(i, deposits[i].signature.length);
            }
        }

        // 6. Verify BLS signatures against the canonical River WC
        _verifyBLSSignatures(deposits, depositYs, withdrawalCredentials);
    }

    function _verifyAttestationQuorum(bytes32 depositDataBufferId, bytes32 depositRootHash, bytes[] calldata signatures)
        internal
        view
    {
        uint256 sigLen = signatures.length;
        if (sigLen > MAX_SIGNATURES) {
            revert TooManySignatures(sigLen, MAX_SIGNATURES);
        }
        uint256 depositCommitteeQuorum = _depositCommitteeQuorum();
        if (depositCommitteeQuorum == 0) revert ZeroQuorum();
        if (sigLen < depositCommitteeQuorum) {
            revert InsufficientAttestations(sigLen, depositCommitteeQuorum);
        }

        bytes32 onChainRoot = _depositContract().get_deposit_root();
        if (onChainRoot != depositRootHash) {
            revert DepositRootMismatch(depositRootHash, onChainRoot);
        }

        bytes32 domainSeparator = _domainSeparator();
        if (domainSeparator == bytes32(0)) revert ZeroDomainSeparator();
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, depositDataBufferId, depositRootHash));
        bytes32 digest = ECDSA.toTypedDataHash(domainSeparator, structHash);

        uint256 validCount = 0;
        address[] memory seen = new address[](sigLen);

        for (uint256 i = 0; i < sigLen; i++) {
            address signer = _recover(digest, signatures[i]);
            if (signer == address(0)) continue;
            if (!_isAttester(signer)) continue;

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

        if (validCount < depositCommitteeQuorum) {
            revert InsufficientAttestations(validCount, depositCommitteeQuorum);
        }
    }

    function _verifyBLSSignatures(
        IDepositDataBuffer.DepositObject[] memory deposits,
        BLS12_381.DepositY[] calldata depositYs,
        bytes32 withdrawalCredentials
    ) internal view {
        for (uint256 i = 0; i < deposits.length; i++) {
            (bool ok, bytes memory revertData) = address(this)
                .staticcall(
                    abi.encodeCall(
                        this.verifyBLSDeposit,
                        (
                            deposits[i].pubkey,
                            deposits[i].signature,
                            deposits[i].amount,
                            depositYs[i],
                            withdrawalCredentials
                        )
                    )
                );
            if (!ok) {
                assembly {
                    revert(add(revertData, 32), mload(revertData))
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // BLS verification helper (called via staticcall for calldata layout)
    // -----------------------------------------------------------------------

    /// @notice Verify a single BLS deposit. Called via staticcall from validate()
    ///         so that memory bytes land in calldata for the BLS12_381 library.
    /// @param pubkey The public key of the deposit
    /// @param signature The signature of the deposit
    /// @param amount The amount of the deposit
    /// @param depositY The Y-coordinate of the deposit
    /// @param withdrawalCredentials The withdrawal credentials of the deposit
    function verifyBLSDeposit(
        bytes calldata pubkey,
        bytes calldata signature,
        uint256 amount,
        BLS12_381.DepositY calldata depositY,
        bytes32 withdrawalCredentials
    ) external view {
        bytes32 depositDomain = _depositDomain();
        if (depositDomain == bytes32(0)) revert ZeroDepositDomain();
        BLS12_381.verifyDepositMessage(pubkey, signature, amount, depositY, withdrawalCredentials, depositDomain);
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// @dev Recover signer from a 65-byte EIP-712 signature, normalizing v.
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
