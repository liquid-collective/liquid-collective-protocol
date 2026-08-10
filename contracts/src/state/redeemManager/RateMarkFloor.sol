//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Rate Mark Floor storage
/// @notice Redeem Manager utility storing the launch cutover for stopped-earning rate marks
/// @dev The lowest position on the cumulative LsETH axis that a rate mark may cover. Set once, at
///      upgrade time, to the total LsETH ever requested at that moment — i.e. the end of the
///      pre-upgrade queue.
///
///      The PRD excludes retroactive application, and a zero `RedeemRequestAnchor` already makes a
///      pre-upgrade request ignore rate marks when its payout is capped. But ignoring a mark is not
///      the same as not consuming one: marks advance a single cursor across the queue, so without a
///      floor the first reports after the upgrade would spend their stopped-earning credit covering
///      pre-upgrade requests that cannot use it, and the first post-upgrade cohort would be
///      short-changed by exactly that amount. The floor makes marking start past them.
library RateMarkFloor {
    /// @notice Storage slot of the Rate Mark Floor
    bytes32 internal constant RATE_MARK_FLOOR_SLOT = bytes32(uint256(keccak256("river.state.rateMarkFloor")) - 1);

    /// @notice Retrieve the Rate Mark Floor value
    /// @return The Rate Mark Floor value
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(RATE_MARK_FLOOR_SLOT);
    }

    /// @notice Sets the Rate Mark Floor value
    /// @param newValue The new value
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(RATE_MARK_FLOOR_SLOT, newValue);
    }
}
