//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Redeem Queue Repaired storage
/// @notice Utility to record that the BS-4878 redeem queue repair has been performed
/// @dev Kept out of the Version counter on purpose. Using `init` would advance Version to 3 on the
///      repaired deployment while every other deployment stays at 2, so the one-off is tracked here
///      instead. Only the recovery implementation reads this slot, and that implementation is upgraded
///      away once the repair is done.
library RedeemQueueRepaired {
    /// @notice Storage slot of the repaired flag
    bytes32 internal constant REDEEM_QUEUE_REPAIRED_SLOT =
        bytes32(uint256(keccak256("river.state.redeemQueueRepaired")) - 1);

    /// @notice Retrieve the repaired flag
    /// @return True if the redeem queue repair has already run
    function get() internal view returns (bool) {
        return LibUnstructuredStorage.getStorageBool(REDEEM_QUEUE_REPAIRED_SLOT);
    }

    /// @notice Sets the repaired flag
    /// @param newValue New repaired flag value
    function set(bool newValue) internal {
        LibUnstructuredStorage.setStorageBool(REDEEM_QUEUE_REPAIRED_SLOT, newValue);
    }
}
