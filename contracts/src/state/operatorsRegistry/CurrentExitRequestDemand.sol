//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title CurrentExitRequestDemand Storage
/// @notice Utility to manage the CurrentExitRequestDemand in storage
library CurrentExitRequestDemand {
    /// @notice Storage slot of the CurrentExitRequestDemand
    bytes32 internal constant CURRENT_EXIT_REQUEST_DEMAND =
        bytes32(uint256(keccak256("river.state.currentExitRequestDemand")) - 1);

    /// @notice Retrieve the CurrentExitRequestDemand
    /// @return The CurrentExitRequestDemand
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CURRENT_EXIT_REQUEST_DEMAND);
    }

    /// @notice Sets the CurrentExitRequestDemand
    /// @param _newValue New CurrentExitRequestDemand
    function set(uint256 _newValue) internal {
        return LibUnstructuredStorage.setStorageUint256(CURRENT_EXIT_REQUEST_DEMAND, _newValue);
    }
}
