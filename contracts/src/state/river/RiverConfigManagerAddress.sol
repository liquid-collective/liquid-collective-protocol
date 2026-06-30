//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title River Config Manager Address Storage
/// @notice Utility to manage the RiverConfigManager address in River storage. The RiverConfigManager
///         holds the bodies of self-contained River functions that River reaches via delegatecall, so
///         it executes in River's storage context.
library RiverConfigManagerAddress {
    /// @notice Storage slot of the RiverConfigManager address
    bytes32 internal constant RIVER_CONFIG_MANAGER_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.riverConfigManagerAddress")) - 1);

    /// @notice Retrieve the RiverConfigManager address
    /// @return The RiverConfigManager address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(RIVER_CONFIG_MANAGER_ADDRESS_SLOT);
    }

    /// @notice Sets the RiverConfigManager address
    /// @param _newValue New RiverConfigManager address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(RIVER_CONFIG_MANAGER_ADDRESS_SLOT, _newValue);
    }
}
