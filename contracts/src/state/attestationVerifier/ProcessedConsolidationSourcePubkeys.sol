//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title ProcessedConsolidationSourcePubkeys
/// @notice Unstructured-storage set of source pubkeys that have already been
///         accepted by `validateConsolidation`.
library ProcessedConsolidationSourcePubkeys {
    bytes32 internal constant PROCESSED_CONSOLIDATION_SOURCE_PUBKEYS_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.processedConsolidationSourcePubkeys.mapping")) - 1);

    /// @notice Check if a consolidation source pubkey has already been consumed.
    /// @param sourcePubkey The raw 48-byte BLS source pubkey.
    /// @return True if the source pubkey was already accepted by a successful consolidation.
    function isProcessed(bytes calldata sourcePubkey) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(PROCESSED_CONSOLIDATION_SOURCE_PUBKEYS_MAPPING_BASE_SLOT, sourcePubkey));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Mark consolidation source pubkeys as consumed.
    /// @param sourcePubkeys The raw 48-byte BLS source pubkeys.
    function markProcessed(bytes[] calldata sourcePubkeys) internal {
        for (uint256 i = 0; i < sourcePubkeys.length; i++) {
            bytes32 slot =
                keccak256(abi.encode(PROCESSED_CONSOLIDATION_SOURCE_PUBKEYS_MAPPING_BASE_SLOT, sourcePubkeys[i]));
            LibUnstructuredStorage.setStorageBool(slot, true);
        }
    }
}
