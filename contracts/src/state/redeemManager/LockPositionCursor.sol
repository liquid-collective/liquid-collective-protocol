//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Lock Position Cursor storage
/// @notice Redeem Manager utility storing where stopped-earning credit resumes on the redeem queue
/// @dev The first position on the cumulative LsETH axis that no report has credited yet. A position
///      rather than a request id, because a stretch a withdrawal event prices before any report
///      reaches it is skipped for good, and only a position records where inside a request that
///      happened. Counting credited width per request instead would let a later report re-credit the
///      skipped stretch, paying a redeemer at a locked rate for demand that was already priced.
///
///      Each report resumes from `max(cursor, settledHeight)`, so the cursor only moves forward and
///      the skipped stretches stay skipped.
library LockPositionCursor {
    /// @notice Storage slot of the Lock Position Cursor
    bytes32 internal constant LOCK_POSITION_CURSOR_SLOT =
        bytes32(uint256(keccak256("river.state.lockPositionCursor")) - 1);

    /// @notice Retrieve the Lock Position Cursor value
    /// @return The Lock Position Cursor value
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(LOCK_POSITION_CURSOR_SLOT);
    }

    /// @notice Sets the Lock Position Cursor value
    /// @param newValue The new value
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(LOCK_POSITION_CURSOR_SLOT, newValue);
    }
}
