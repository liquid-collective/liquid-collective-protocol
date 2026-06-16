//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title Consolidation Manager Address Storage
/// @notice Utility to manage the ConsolidationManager address in River storage.
library ConsolidationManagerAddress {
    /// @notice Storage slot of the ConsolidationManager address
    bytes32 internal constant CONSOLIDATION_MANAGER_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.consolidationManagerAddress")) - 1);

    /// @notice Retrieve the ConsolidationManager address
    /// @return The ConsolidationManager address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(CONSOLIDATION_MANAGER_ADDRESS_SLOT);
    }

    /// @notice Sets the ConsolidationManager address
    /// @param _newValue New ConsolidationManager address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(CONSOLIDATION_MANAGER_ADDRESS_SLOT, _newValue);
    }
}
