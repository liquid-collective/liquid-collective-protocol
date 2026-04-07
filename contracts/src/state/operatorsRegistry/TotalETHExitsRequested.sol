//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title TotalETHExitsRequested Storage
/// @notice This value is the amount of performed exit requests, only increased when there is current exit demand
/// @notice Utility to manage the TotalETHExitsRequested in storage
/// @dev This value is in ETH(wei)
library TotalETHExitsRequested {
    /// @notice Storage slot of the TotalETHExitsRequested
    bytes32 internal constant TOTAL_ETH_EXITS_REQUESTED_SLOT =
        bytes32(uint256(keccak256("river.state.totalETHExitsRequested")) - 1);

    /// @notice Retrieve the TotalETHExitsRequested
    /// @return The TotalETHExitsRequested
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(TOTAL_ETH_EXITS_REQUESTED_SLOT);
    }

    /// @notice Sets the TotalETHExitsRequested
    /// @param _newValue New TotalETHExitsRequested
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(TOTAL_ETH_EXITS_REQUESTED_SLOT, _newValue);
    }
}
