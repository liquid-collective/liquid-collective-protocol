//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Rate Mark Start storage
/// @notice Redeem Manager utility storing the start of the next mark
/// @dev The start of the next rate mark on the cumulative LsETH axis. This value advances as rate marks are applied to redeem requests.
library RateMarkStart {
    /// @notice Storage slot of the Rate Mark Start
    bytes32 internal constant RATE_MARK_START_SLOT = bytes32(uint256(keccak256("river.state.rateMarkStart")) - 1);

    /// @notice Retrieve the Rate Mark Start value
    /// @return The Rate Mark Start value
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(RATE_MARK_START_SLOT);
    }

    /// @notice Sets the Rate Mark Start value
    /// @param newValue The new value
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(RATE_MARK_START_SLOT, newValue);
    }
}
