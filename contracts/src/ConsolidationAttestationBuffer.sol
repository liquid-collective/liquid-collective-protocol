//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IConsolidationAttestationBuffer.sol";

/// @title ConsolidationAttestationBuffer (v1)
/// @author Alluvial Finance Inc.
/// @notice A simple, non-upgradeable contract that emits consolidation attestation events on-chain.
///         Anyone can submit attestations; off-chain daemons collect the events. Signature recovery
///         and quorum validation are performed elsewhere.
/// @dev Unhappy path: anyone may flag a consolidation hash as errored via `raiseError`. Attribution
///      is by `msg.sender` (emitted as `raiser`); the off-chain backend decides whether the raiser
///      is one of its daemons/committee members and should be listened to. A flag is a sticky,
///      hard on-chain stop: `submitAttestation` reverts for a flagged hash, so no further
///      signatures are aggregated on-chain. Invalid pubkey storage is first-report-wins, while
///      duplicate error reports continue to emit for off-chain attribution.
contract ConsolidationAttestationBuffer is IConsolidationAttestationBuffer {
    /// @dev Buffer-local EIP-712 struct hash including `exitEpoch`.
    bytes32 internal constant ATTEST_CONSOLIDATION_TYPEHASH = keccak256(
        "AttestConsolidation(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount,uint256 exitEpoch)"
    );

    /// @inheritdoc IConsolidationAttestationBuffer
    uint256 public lastAttestationIdx;

    /// @inheritdoc IConsolidationAttestationBuffer
    uint256 public lastErrorIdx;

    /// @dev consolidationHash => flagged errored.
    mapping(bytes32 => bool) internal _errored;

    /// @dev consolidationHash => invalid pubkeys from the first error report for that hash.
    mapping(bytes32 => bytes[]) internal _invalidPubkeysByHash;

    /// @dev keccak256(pubkey) => recorded invalid by a first error report.
    mapping(bytes32 => bool) internal _invalidPubkeyHashes;

    /// @inheritdoc IConsolidationAttestationBuffer
    function submitAttestation(ConsolidationObject calldata consolidation, bytes calldata signature) external {
        bytes32 consolidationHash = _computeConsolidationHash(consolidation);
        if (_errored[consolidationHash]) revert ConsolidationNotReady(consolidationHash);
        _revertIfInvalidPubkeys(consolidation);

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
    function raiseError(
        ConsolidationObject calldata consolidation,
        bytes[] calldata invalidPubkeys,
        uint256 errorCode,
        bytes calldata errorMessage
    ) external {
        bytes32 consolidationHash = _computeConsolidationHash(consolidation);

        if (!_errored[consolidationHash]) {
            _errored[consolidationHash] = true;
            bytes[] storage storedInvalidPubkeys = _invalidPubkeysByHash[consolidationHash];
            for (uint256 i = 0; i < invalidPubkeys.length; i++) {
                storedInvalidPubkeys.push(invalidPubkeys[i]);
                _invalidPubkeyHashes[keccak256(invalidPubkeys[i])] = true;
            }
            emit InvalidConsolidationPubkeysRecorded(consolidationHash, invalidPubkeys);
        }

        emit ConsolidationAttestationError(
            lastErrorIdx, consolidationHash, msg.sender, errorCode, errorMessage, invalidPubkeys
        );
        ++lastErrorIdx;
    }

    /// @inheritdoc IConsolidationAttestationBuffer
    function computeConsolidationHash(ConsolidationObject calldata consolidation) external pure returns (bytes32) {
        return _computeConsolidationHash(consolidation);
    }

    /// @inheritdoc IConsolidationAttestationBuffer
    function isConsolidationErrored(bytes32 consolidationHash) external view returns (bool) {
        return _errored[consolidationHash];
    }

    /// @inheritdoc IConsolidationAttestationBuffer
    function getInvalidPubkeys(bytes32 consolidationHash) external view returns (bytes[] memory) {
        return _invalidPubkeysByHash[consolidationHash];
    }

    /// @inheritdoc IConsolidationAttestationBuffer
    function invalidPubkeyCount(bytes32 consolidationHash) external view returns (uint256) {
        return _invalidPubkeysByHash[consolidationHash].length;
    }

    /// @inheritdoc IConsolidationAttestationBuffer
    function invalidPubkeyAt(bytes32 consolidationHash, uint256 index) external view returns (bytes memory) {
        return _invalidPubkeysByHash[consolidationHash][index];
    }

    /// @inheritdoc IConsolidationAttestationBuffer
    function isInvalidPubkey(bytes calldata pubkey) external view returns (bool) {
        return _isInvalidPubkey(pubkey);
    }

    /// @inheritdoc IConsolidationAttestationBuffer
    function isInvalidPubkeyHash(bytes32 pubkeyHash) external view returns (bool) {
        return _invalidPubkeyHashes[pubkeyHash];
    }

    /// @inheritdoc IConsolidationAttestationBuffer
    function hasInvalidPubkeys(ConsolidationObject calldata consolidation) external view returns (bool) {
        for (uint256 i = 0; i < consolidation.sourcePubkeys.length; i++) {
            if (_isInvalidPubkey(consolidation.sourcePubkeys[i])) return true;
        }
        for (uint256 i = 0; i < consolidation.targetPubkeys.length; i++) {
            if (_isInvalidPubkey(consolidation.targetPubkeys[i])) return true;
        }
        return false;
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

    function _isInvalidPubkey(bytes calldata pubkey) internal view returns (bool) {
        return _invalidPubkeyHashes[keccak256(pubkey)];
    }

    function _revertIfInvalidPubkeys(ConsolidationObject calldata consolidation) internal view {
        for (uint256 i = 0; i < consolidation.sourcePubkeys.length; i++) {
            if (_isInvalidPubkey(consolidation.sourcePubkeys[i])) {
                revert InvalidConsolidationPubkey(consolidation.sourcePubkeys[i]);
            }
        }
        for (uint256 i = 0; i < consolidation.targetPubkeys.length; i++) {
            if (_isInvalidPubkey(consolidation.targetPubkeys[i])) {
                revert InvalidConsolidationPubkey(consolidation.targetPubkeys[i]);
            }
        }
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
