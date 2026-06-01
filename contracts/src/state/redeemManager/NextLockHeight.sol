//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Next Lock Height storage
/// @notice Redeem Manager utility to store the height used by the next appended MaxRedeemableETHLockedEvent
/// @dev Bootstrapped to RedeemDemand_at_upgrade in initializeRedeemManagerV1_3 so the first post-upgrade
///      lock event sits behind all pre-upgrade requests (lock events never cover pre-upgrade slices).
///      Advanced by `_lsETHToLock` after each lockMaxRedeemableETH append.
library NextLockHeight {
    /// @notice Storage slot of the Next Lock Height
    bytes32 internal constant NEXT_LOCK_HEIGHT_SLOT =
        bytes32(uint256(keccak256("river.state.nextLockHeight")) - 1);

    /// @notice Retrieve the Next Lock Height value
    /// @return The Next Lock Height value
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(NEXT_LOCK_HEIGHT_SLOT);
    }

    /// @notice Sets the Next Lock Height value
    /// @param newValue The new value
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(NEXT_LOCK_HEIGHT_SLOT, newValue);
    }
}
