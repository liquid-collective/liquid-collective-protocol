//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/IDepositAttestation.sol";

/// @title DepositAttestation (v1)
/// @author Alluvial Finance Inc.
/// @notice A non-upgradeable contract that verifies committee attestation signatures on-chain and
///         emits them as events for off-chain collection. Each attestation is either an approval or a
///         faulty-batch flag, distinguished by whether `errorData` is empty.
/// @dev The signature must recover to `msg.sender` over the EIP-712 digest built from this buffer's
///      domain separator — so the attester submits their own attestation. The domain separator is the
///      same one used by the L1 AttestationVerifier (EIP-712 name/version + L1 chainId + River
///      address), so an approval signature verified here is byte-for-byte the signature the L1
///      verifier consumes for the deposit quorum. A faulty-batch flag is signed over a distinct
///      `AttestError` typehash, which makes it inert in the L1 deposit quorum (the verifier computes
///      the `Attest` struct hash and would recover a different signer). `errorData` is opaque to this
///      contract: it is hashed into the signed digest and emitted verbatim for keepers to interpret.
contract DepositAttestation is IDepositAttestation {
    /// @notice EIP-712 typehash for an approval attestation. Identical to the L1 AttestationVerifier's.
    bytes32 public constant ATTEST_TYPEHASH = keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");

    /// @notice EIP-712 typehash for a faulty-batch attestation carrying an error payload.
    bytes32 public constant ATTEST_ERROR_TYPEHASH =
        keccak256("AttestError(bytes32 depositDataBufferId,bytes32 depositRootHash,bytes errorData)");

    /// @notice The EIP-712 domain separator used to verify attestation signatures.
    /// @dev Set once at construction; must equal `AttestationVerifierV1.getDomainSeparator()` so that
    ///      approval signatures verified here are consumable on L1.
    bytes32 internal immutable _domainSeparator;

    /// @inheritdoc IDepositAttestation
    uint256 public lastAttestationIdx;

    /// @param domainSeparator The EIP-712 domain separator (must equal the L1 verifier's).
    constructor(bytes32 domainSeparator) {
        if (domainSeparator == bytes32(0)) revert ZeroDomainSeparator();
        _domainSeparator = domainSeparator;
    }

    /// @inheritdoc IDepositAttestation
    function submitAttestation(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes calldata signature,
        bytes calldata errorData
    ) external {
        // An empty payload is an approval (Attest); a non-empty payload flags a faulty batch
        // (AttestError). The two struct types have distinct typehashes, so a signature over one
        // cannot be replayed as the other.
        bytes32 structHash = errorData.length == 0
            ? keccak256(abi.encode(ATTEST_TYPEHASH, depositDataBufferId, depositRootHash))
            : keccak256(abi.encode(ATTEST_ERROR_TYPEHASH, depositDataBufferId, depositRootHash, keccak256(errorData)));

        bytes32 digest = ECDSA.toTypedDataHash(_domainSeparator, structHash);
        if (_recoverSigner(digest, signature) != msg.sender) revert InvalidAttestationSignature();

        emit AttestationSubmitted(lastAttestationIdx, depositDataBufferId, depositRootHash, signature, errorData);
        ++lastAttestationIdx;
    }

    /// @inheritdoc IDepositAttestation
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparator;
    }

    /// @notice Recover the signer of `digest` from a 65-byte signature, returning address(0) on any
    ///         malformed input. Mirrors the L1 AttestationVerifier's recovery (v normalization + OZ
    ///         `tryRecover` low-s enforcement) so the two contracts accept the same signatures.
    /// @param digest The EIP-712 digest that was signed.
    /// @param sig The 65-byte signature.
    /// @return The recovered signer, or address(0) if recovery fails.
    function _recoverSigner(bytes32 digest, bytes calldata sig) internal pure returns (address) {
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
