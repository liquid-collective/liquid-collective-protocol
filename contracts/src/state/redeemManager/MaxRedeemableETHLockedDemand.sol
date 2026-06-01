//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Max Redeemable ETH Locked Demand storage
/// @notice Redeem Manager utility to store the LsETH amount currently covered by a lock event but not yet by a withdrawal event
/// @dev Invariant: MaxRedeemableETHLockedDemand <= RedeemDemand at all times.
///      Incremented in lockMaxRedeemableETH, decremented in reportWithdraw by min(_lsETHWithdrawable, get()).
library MaxRedeemableETHLockedDemand {
    /// @notice Storage slot of the Max Redeemable ETH Locked Demand
    bytes32 internal constant MAX_REDEEMABLE_ETH_LOCKED_DEMAND_SLOT =
        bytes32(uint256(keccak256("river.state.maxRedeemableEthLockedDemand")) - 1);

    /// @notice Retrieve the Max Redeemable ETH Locked Demand value
    /// @return The Max Redeemable ETH Locked Demand value
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(MAX_REDEEMABLE_ETH_LOCKED_DEMAND_SLOT);
    }

    /// @notice Sets the Max Redeemable ETH Locked Demand value
    /// @param newValue The new value
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(MAX_REDEEMABLE_ETH_LOCKED_DEMAND_SLOT, newValue);
    }
}
