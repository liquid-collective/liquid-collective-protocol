//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Redeem Manager Max Redeemable ETH Locked Stack storage
/// @notice Utility to manage the stack of MaxRedeemableETH lock events in the Redeem Manager
/// @dev Each lock event records the new maxRedeemableEth cap for a slice of the redeem queue,
///      pegged at the rate at which the underlying ETH backing that slice became inactive
///      (validator exit_epoch, partial-withdrawal withdrawable_epoch, or deposit-redeem rebalance).
library MaxRedeemableETHLockedStack {
    /// @notice Storage slot of the Max Redeemable ETH Locked Stack
    bytes32 internal constant MAX_REDEEMABLE_ETH_LOCKED_STACK_SLOT =
        bytes32(uint256(keccak256("river.state.maxRedeemableEthLockedStack")) - 1);

    /// @notice A MaxRedeemableETHLockedEvent records the new cap for a contiguous LsETH slice
    /// @dev `height` is the cumulative position of this slice in the redeem queue, in LsETH.
    ///      `amount` is the LsETH-equivalent size of the slice this event covers.
    ///      `lockedEth` is the ETH-denominated cap for the slice (current rate × amount at lock time).
    struct MaxRedeemableETHLockedEvent {
        /// @custom:attribute Cumulative LsETH position covered by prior lock events
        uint256 height;
        /// @custom:attribute LsETH-equivalent of this lock slice
        uint256 amount;
        /// @custom:attribute The new maxRedeemableEth cap for this slice (rate at lock time × amount)
        uint256 lockedEth;
    }

    /// @notice Retrieve the Max Redeemable ETH Locked Stack array storage pointer
    /// @return data The Max Redeemable ETH Locked Stack array storage pointer
    function get() internal pure returns (MaxRedeemableETHLockedEvent[] storage data) {
        bytes32 position = MAX_REDEEMABLE_ETH_LOCKED_STACK_SLOT;
        assembly {
            data.slot := position
        }
    }
}
