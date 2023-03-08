//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title LastReportedEpochId Storage
/// @notice Utility to manage the LastReportedEpochId in storage
library LastReportedEpochId {
    /// @notice Storage slot of the LastReportedEpochId
    bytes32 internal constant LAST_REPORTED_EPOCH_ID_SLOT =
        bytes32(uint256(keccak256("river.state.lastReportedEpochId")) - 1);

    /// @notice Retrieve the LastReportedEpochId
    /// @return The LastReportedEpochId
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(LAST_REPORTED_EPOCH_ID_SLOT);
    }

    /// @notice Sets the LastReportedEpochId
    /// @param _newValue New LastReportedEpochId
    function set(uint256 _newValue) internal {
        return LibUnstructuredStorage.setStorageUint256(LAST_REPORTED_EPOCH_ID_SLOT, _newValue);
    }
}
