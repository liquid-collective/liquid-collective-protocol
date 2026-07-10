//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IConsolidationAttestationBuffer.sol";

/// @title ConsolidationAttestationBuffer (v1)
/// @author Alluvial Finance Inc.
/// @notice A simple, non-upgradeable contract that emits consolidation attestation events on-chain.
///         Anyone can submit attestations; off-chain daemons collect the events. Signature recovery
///         and quorum validation are performed elsewhere.
contract ConsolidationAttestationBuffer is IConsolidationAttestationBuffer {
    /// @dev Buffer-local EIP-712 struct hash including `exitEpoch`.
    bytes32 internal constant ATTEST_CONSOLIDATION_TYPEHASH = keccak256(
        "AttestConsolidation(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount,uint256 exitEpoch)"
    );

    /// @inheritdoc IConsolidationAttestationBuffer
    uint256 public lastAttestationIdx;

    /// @inheritdoc IConsolidationAttestationBuffer
    function submitAttestation(ConsolidationObject calldata consolidation, bytes calldata signature) external {
        bytes32 consolidationHash = _computeConsolidationHash(consolidation);

        emit ConsolidationAttestationSubmitted(
            lastAttestationIdx,
            consolidationHash,
            consolidation.withdrawalAddress,
            consolidation.sourcePubkeys,
            consolidation.targetPubkeys,
            consolidation.totalAmount,
            consolidation.exitEpoch,
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
}
