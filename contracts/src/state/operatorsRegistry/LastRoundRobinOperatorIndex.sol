//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title LastRoundRobinOperatorIndex Storage
/// @notice This value is the index of the last node operator that received a validator in round-robin mode
/// @notice Utility to manage the LastRoundRobinOperatorIndex in storage
library LastRoundRobinOperatorIndex {
    /// @notice Storage slot of the LastRoundRobinOperatorIndex
    bytes32 internal constant LAST_ROUND_ROBIN_OPERATOR_INDEX_SLOT =
        bytes32(uint256(keccak256("river.state.lastRoundRobinOperatorIndex")) - 1);

    /// @notice Retrieve the LastRoundRobinOperatorIndex
    /// @return The LastRoundRobinOperatorIndex
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(LAST_ROUND_ROBIN_OPERATOR_INDEX_SLOT);
    }

    /// @notice Sets the LastRoundRobinOperatorIndex
    /// @param _newValue New LastRoundRobinOperatorIndex
    function set(uint256 _newValue) internal {
        return LibUnstructuredStorage.setStorageUint256(LAST_ROUND_ROBIN_OPERATOR_INDEX_SLOT, _newValue);
    }
}
