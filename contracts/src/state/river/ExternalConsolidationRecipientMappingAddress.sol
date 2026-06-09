//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title External Consolidation Recipient Mapping Address Storage
/// @notice Utility to manage the External Consolidation Recipient Mapping Address in storage
library ExternalConsolidationRecipientMappingAddress {
    /// @notice Storage slot of the External Consolidation Recipient Mapping Address
    bytes32 internal constant EXTERNAL_CONSOLIDATION_RECIPIENT_MAPPING_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.externalConsolidationRecipientMappingAddress")) - 1);

    /// @notice Retrieve the External Consolidation Recipient Mapping Address
    /// @return The External Consolidation Recipient Mapping Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(EXTERNAL_CONSOLIDATION_RECIPIENT_MAPPING_ADDRESS_SLOT);
    }

    /// @notice Sets the External Consolidation Recipient Mapping Address
    /// @param _newValue New External Consolidation Recipient Mapping Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(EXTERNAL_CONSOLIDATION_RECIPIENT_MAPPING_ADDRESS_SLOT, _newValue);
    }
}
