//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title ProcessedConsolidations
/// @notice Unstructured storage library tracking consolidation requests that have already
///         been accepted by `validateConsolidation`, keyed by their EIP-712 structHash.
///         Used for replay protection so the same consolidation request cannot be validated
///         twice.
///         Membership uses a slot-based mapping:
///         slot = keccak256(abi.encode(PROCESSED_CONSOLIDATIONS_MAPPING_BASE_SLOT, consolidationHash))
library ProcessedConsolidations {
    bytes32 internal constant PROCESSED_CONSOLIDATIONS_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.processedConsolidations.mapping")) - 1);

    /// @notice Check if a consolidation has already been processed.
    /// @param consolidationHash The EIP-712 structHash of the consolidation request
    /// @return True if the request has already been validated by `validateConsolidation`
    function isProcessed(bytes32 consolidationHash) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(PROCESSED_CONSOLIDATIONS_MAPPING_BASE_SLOT, consolidationHash));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Mark a consolidation as processed.
    /// @param consolidationHash The EIP-712 structHash of the consolidation request
    function markProcessed(bytes32 consolidationHash) internal {
        bytes32 slot = keccak256(abi.encode(PROCESSED_CONSOLIDATIONS_MAPPING_BASE_SLOT, consolidationHash));
        LibUnstructuredStorage.setStorageBool(slot, true);
    }
}
