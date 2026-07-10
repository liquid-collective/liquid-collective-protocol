//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/IConsolidationAttestationBuffer.sol";

/// @title ConsolidationAttestationBuffer (v1)
/// @author Alluvial Finance Inc.
/// @notice A simple, non-upgradeable contract that emits consolidation attestation events on-chain.
///         Anyone can submit attestations; off-chain daemons collect the events. Quorum validation
///         is performed elsewhere.
/// @dev Each submission carries a signature that must be produced by `msg.sender`. When `error` is
///      empty the signature is over `keccak256(abi.encode(consolidation))`; when `error` is non-empty
///      it is over `keccak256(abi.encode(consolidation, error))`. This binds the submitter to the
///      exact consolidation object (and optional error) they are attesting to.
contract ConsolidationAttestationBuffer is IConsolidationAttestationBuffer {
    /// @dev Buffer-local EIP-712 struct hash including `exitEpoch`.
    bytes32 internal constant ATTEST_CONSOLIDATION_TYPEHASH = keccak256(
        "AttestConsolidation(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount,uint256 exitEpoch)"
    );

    /// @inheritdoc IConsolidationAttestationBuffer
    uint256 public lastAttestationIdx;

    /// @inheritdoc IConsolidationAttestationBuffer
    function submitAttestation(
        ConsolidationObject calldata consolidation,
        bytes calldata error,
        bytes calldata signature
    ) external {
        bytes32 consolidationHash = _computeConsolidationHash(consolidation);

        bytes32 digest =
            error.length == 0 ? keccak256(abi.encode(consolidation)) : keccak256(abi.encode(consolidation, error));
        if (_recover(digest, signature) != msg.sender) revert InvalidSignature();

        emit ConsolidationAttestationSubmitted(
            lastAttestationIdx,
            consolidationHash,
            consolidation.withdrawalAddress,
            consolidation.sourcePubkeys,
            consolidation.targetPubkeys,
            consolidation.totalAmount,
            consolidation.exitEpoch,
            error,
            signature
        );
        ++lastAttestationIdx;
    }

    /// @inheritdoc IConsolidationAttestationBuffer
    function computeConsolidationHash(ConsolidationObject calldata consolidation) external pure returns (bytes32) {
        return _computeConsolidationHash(consolidation);
    }

    function _computeConsolidationHash(ConsolidationObject calldata consolidation) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_TYPEHASH,
                consolidation.withdrawalAddress,
                _hashBytesArray(consolidation.sourcePubkeys),
                _hashBytesArray(consolidation.targetPubkeys),
                consolidation.totalAmount,
                consolidation.exitEpoch
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
