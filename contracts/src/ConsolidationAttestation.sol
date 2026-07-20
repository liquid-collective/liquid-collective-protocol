//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/IConsolidationAttestation.sol";

/// @title ConsolidationAttestation (v1)
/// @author Alluvial Finance Inc.
/// @notice A simple, non-upgradeable contract that emits consolidation attestation events on-chain.
///         Anyone can submit attestations; off-chain daemons collect the events. Quorum validation
///         is performed elsewhere.
/// @dev Each submission carries a signature that must be produced by `msg.sender`. When `errorData`
///      is empty the signature is over the same five-field `AttestConsolidation` EIP-712 struct that
///      the L1 AttestationVerifier consumes, which binds the per-consolidation `exitEpoch` array.
///      When `errorData` is non-empty the signature is over a distinct L2-only
///      `AttestConsolidationError` struct that additionally binds the error payload.
contract ConsolidationAttestation is IConsolidationAttestation {
    /// @notice EIP-712 typehash for a consolidation approval. Identical to the L1 verifier's.
    bytes32 public constant ATTEST_CONSOLIDATION_TYPEHASH = keccak256(
        "AttestConsolidation(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount,uint256[] exitEpoch)"
    );

    /// @notice EIP-712 typehash for a consolidation error attestation carrying an error payload.
    bytes32 public constant ATTEST_CONSOLIDATION_ERROR_TYPEHASH = keccak256(
        "AttestConsolidationError(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount,uint256[] exitEpoch,bytes errorData)"
    );

    /// @notice The EIP-712 domain separator used to verify attestation signatures.
    bytes32 internal immutable _domainSeparator;

    /// @inheritdoc IConsolidationAttestation
    uint256 public lastAttestationIdx;

    /// @param domainSeparator The EIP-712 domain separator used for consolidation attestations.
    constructor(bytes32 domainSeparator) {
        if (domainSeparator == bytes32(0)) revert ZeroDomainSeparator();
        _domainSeparator = domainSeparator;
    }

    /// @inheritdoc IConsolidationAttestation
    function submitAttestation(
        ConsolidationObject calldata consolidation,
        bytes calldata signature,
        bytes calldata errorData
    ) external {
        bytes32 consolidationHash = _computeConsolidationHash(consolidation);

        bytes32 structHash =
            errorData.length == 0 ? consolidationHash : _computeConsolidationErrorHash(consolidation, errorData);
        bytes32 digest = ECDSA.toTypedDataHash(_domainSeparator, structHash);
        if (_recover(digest, signature) != msg.sender) revert InvalidSignature();

        emit ConsolidationAttestationSubmitted(
            lastAttestationIdx,
            consolidationHash,
            consolidation.withdrawalAddress,
            consolidation.sourcePubkeys,
            consolidation.targetPubkeys,
            consolidation.totalAmount,
            consolidation.exitEpoch,
            signature,
            errorData
        );
        ++lastAttestationIdx;
    }

    /// @inheritdoc IConsolidationAttestation
    function computeConsolidationHash(ConsolidationObject calldata consolidation) external pure returns (bytes32) {
        return _computeConsolidationHash(consolidation);
    }

    /// @inheritdoc IConsolidationAttestation
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparator;
    }

    function _computeConsolidationHash(ConsolidationObject calldata consolidation) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_TYPEHASH,
                consolidation.withdrawalAddress,
                _hashBytesArray(consolidation.sourcePubkeys),
                _hashBytesArray(consolidation.targetPubkeys),
                consolidation.totalAmount,
                _hashUintArray(consolidation.exitEpoch)
            )
        );
    }

    function _computeConsolidationErrorHash(ConsolidationObject calldata consolidation, bytes calldata errorData)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_ERROR_TYPEHASH,
                consolidation.withdrawalAddress,
                _hashBytesArray(consolidation.sourcePubkeys),
                _hashBytesArray(consolidation.targetPubkeys),
                consolidation.totalAmount,
                _hashUintArray(consolidation.exitEpoch),
                keccak256(errorData)
            )
        );
    }

    /// @dev EIP-712 array hash for a `bytes[]` field. Each element is replaced by its
    ///      `keccak256`, and the resulting `bytes32[]` is concatenated and hashed.
    function _hashBytesArray(bytes[] calldata arr) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            hashes[i] = keccak256(arr[i]);
        }
        return keccak256(abi.encodePacked(hashes));
    }

    /// @dev EIP-712 array hash for a `uint256[]` field. Each element is already an atomic
    ///      32-byte value, so the array hashes to `keccak256` over their concatenation.
    function _hashUintArray(uint256[] calldata arr) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(arr));
    }

    /// @dev Recover signer from a 65-byte signature, normalizing v. Returns `address(0)` on any
    ///      malformed signature so the caller's `msg.sender` equality check reverts.
    /// @param digest The digest that was signed.
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
