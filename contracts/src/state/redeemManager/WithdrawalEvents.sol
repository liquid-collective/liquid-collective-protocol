//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/// @title Redeem Manager Withdrawal Events storage
/// @notice Utility to manage the Withdrawal Events in the Redeem Manager
library WithdrawalEvents {
    /// @notice Storage slot of the Withdrawal Events
    bytes32 internal constant WITHDRAWAL_EVENTS_ID_SLOT =
        bytes32(uint256(keccak256("river.state.withdrawalEvents")) - 1);

    /// @notice The Redeemer structure represents the withdrawal events made by River
    struct WithdrawalEvent {
        /// @custom:attribute The amount of the withdrawal event in LsETH
        uint256 amount;
        /// @custom:attribute The amount of the withdrawal event in ETH
        uint256 withdrawnEth;
        /// @custom:attribute The height is the cumulative sum of all the sizes of preceding withdrawal events
        uint256 height;
    }

    /// @notice Retrieve the Withdrawal Events array storage pointer
    /// @return data The Withdrawal Events array storage pointer
    function get() internal pure returns (WithdrawalEvent[] storage data) {
        bytes32 position = WITHDRAWAL_EVENTS_ID_SLOT;
        assembly {
            data.slot := position
        }
    }
}
