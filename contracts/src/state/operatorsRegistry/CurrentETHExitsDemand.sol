//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title CurrentETHExitsDemand Storage
/// @notice This value controls the current demand for exits that still need to be triggered
/// @notice in order to notify the operators
/// @notice Utility to manage the CurrentETHExitsDemand in storage
library CurrentETHExitsDemand {
    /// @notice Storage slot of the CurrentETHExitsDemand
    bytes32 internal constant CURRENT_ETH_EXITS_DEMAND_SLOT =
        bytes32(uint256(keccak256("river.state.currentETHExitsDemand")) - 1);

    /// @notice Retrieve the CurrentETHExitsDemand
    /// @return The CurrentETHExitsDemand
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CURRENT_ETH_EXITS_DEMAND_SLOT);
    }

    /// @notice Sets the CurrentETHExitsDemand
    /// @param _newValue New CurrentETHExitsDemand
    function set(uint256 _newValue) internal {
        return LibUnstructuredStorage.setStorageUint256(CURRENT_ETH_EXITS_DEMAND_SLOT, _newValue);
    }
}
