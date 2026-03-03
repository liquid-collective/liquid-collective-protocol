//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title PendingFullExitBalance Storage
/// @notice Tracks the total ETH amount of validators that have been requested to exit but have not yet exited
library PendingFullExitBalance {
    bytes32 internal constant PENDING_FULL_EXIT_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.pendingFullExitBalance")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(PENDING_FULL_EXIT_BALANCE_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(PENDING_FULL_EXIT_BALANCE_SLOT, newValue);
    }
}
