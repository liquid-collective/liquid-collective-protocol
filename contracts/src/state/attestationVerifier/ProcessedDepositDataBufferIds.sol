//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title ProcessedDepositDataBufferIds
/// @notice Unstructured storage library tracking deposit data buffer IDs that have already
///         been executed through `depositToConsensusLayerWithAttestation`. Used for replay
///         protection so the same batch ID cannot be validated twice.
///         Membership uses a slot-based mapping:
///         slot = keccak256(abi.encode(PROCESSED_DEPOSIT_DATA_BUFFER_IDS_MAPPING_BASE_SLOT, depositDataBufferId))
///
/// @dev    Replay protection is critical for top-ups: a replayed initial-deposit batch
///         would already fail because every pubkey is in `ValidatorPubkeyLookup` after the
///         first execution, but top-ups *require* their pubkeys to be in the lookup, so a
///         second call with the same `depositDataBufferId` and attestations would otherwise
///         re-execute the top-up transfers. The DepositDataBuffer is also expected to
///         produce a unique `depositDataBufferId` per submission (see IDepositDataBuffer
///         natspec), so this mapping is a defense-in-depth on the verifier side.
library ProcessedDepositDataBufferIds {
    bytes32 internal constant PROCESSED_DEPOSIT_DATA_BUFFER_IDS_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.processedDepositDataBufferIds.mapping")) - 1);

    /// @notice Check if a deposit data buffer ID has already been processed.
    /// @param depositDataBufferId The batch identifier.
    /// @return True if the ID has been processed.
    function isProcessed(bytes32 depositDataBufferId) internal view returns (bool) {
        bytes32 slot =
            keccak256(abi.encode(PROCESSED_DEPOSIT_DATA_BUFFER_IDS_MAPPING_BASE_SLOT, depositDataBufferId));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Mark a deposit data buffer ID as processed.
    /// @param depositDataBufferId The batch identifier.
    function markProcessed(bytes32 depositDataBufferId) internal {
        bytes32 slot =
            keccak256(abi.encode(PROCESSED_DEPOSIT_DATA_BUFFER_IDS_MAPPING_BASE_SLOT, depositDataBufferId));
        LibUnstructuredStorage.setStorageBool(slot, true);
    }
}
