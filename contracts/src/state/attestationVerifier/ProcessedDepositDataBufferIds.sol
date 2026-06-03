//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title ProcessedDepositDataBufferIds
/// @notice Set of deposit data buffer IDs already executed by `depositToConsensusLayerWithAttestation`,
///         consulted by `validate()` to reject replays. Critical for top-ups, whose pubkey-in-lookup
///         precondition is unchanged after the first execution.
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
