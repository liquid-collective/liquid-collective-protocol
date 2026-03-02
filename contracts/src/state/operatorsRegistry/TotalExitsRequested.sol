//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Total Exits Requested Storage
/// @notice Utility to manage the Total Exits Requested in storage
library TotalExitsRequested {
    /// @notice Storage slot of the Total Exits Requested
    bytes32 internal constant TOTAL_EXITS_REQUESTED_SLOT =
        bytes32(uint256(keccak256("river.state.totalExitsRequested")) - 1);

    /// @notice Retrieve the Total Exits Requested
    /// @return The Total Exits Requested
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(TOTAL_EXITS_REQUESTED_SLOT);
    }

    /// @notice Sets the Total Exits Requested
    /// @param _newValue New Total Exits Requested
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(TOTAL_EXITS_REQUESTED_SLOT, _newValue);
    }
}
