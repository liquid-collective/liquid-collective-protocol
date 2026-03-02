//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Current Exit Demand Storage
/// @notice Utility to manage the Current Exit Demand in storage
library CurrentExitDemand {
    /// @notice Storage slot of the Current Exit Demand
    bytes32 internal constant CURRENT_EXIT_DEMAND_SLOT =
        bytes32(uint256(keccak256("river.state.currentExitDemand")) - 1);

    /// @notice Retrieve the Current Exit Demand
    /// @return The Current Exit Demand
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CURRENT_EXIT_DEMAND_SLOT);
    }

    /// @notice Sets the Current Exit Demand
    /// @param _newValue New Current Exit Demand
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(CURRENT_EXIT_DEMAND_SLOT, _newValue);
    }
}
