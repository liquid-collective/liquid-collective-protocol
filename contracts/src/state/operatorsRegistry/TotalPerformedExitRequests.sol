//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title TotalPerformedExitRequests Storage
/// @notice Utility to manage the TotalPerformedExitRequests in storage
library TotalPerformedExitRequests {
    /// @notice Storage slot of the TotalPerformedExitRequests
    bytes32 internal constant TOTAL_PERFORMED_EXIT_REQUESTS =
        bytes32(uint256(keccak256("river.state.totalPerformedExitRequests")) - 1);

    /// @notice Retrieve the TotalPerformedExitRequests
    /// @return The TotalPerformedExitRequests
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(TOTAL_PERFORMED_EXIT_REQUESTS);
    }

    /// @notice Sets the TotalPerformedExitRequests
    /// @param _newValue New TotalPerformedExitRequests
    function set(uint256 _newValue) internal {
        return LibUnstructuredStorage.setStorageUint256(TOTAL_PERFORMED_EXIT_REQUESTS, _newValue);
    }
}
