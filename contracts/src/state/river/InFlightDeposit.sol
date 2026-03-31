//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title InFlightDeposit Storage
/// @notice This value is the in flight ETH
/// @notice Utility to manage the InFlightDeposit in storage
library InFlightDeposit {
    /// @notice Storage slot of the InFlightDeposit
    bytes32 internal constant IN_FLIGHT_DEPOSIT_SLOT = bytes32(uint256(keccak256("river.state.inFlightDeposit")) - 1);

    /// @notice Retrieve the InFlightDeposit
    /// @return The InFlightDeposit
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(IN_FLIGHT_DEPOSIT_SLOT);
    }

    /// @notice Sets the InFlightDeposit
    /// @param _newValue New InFlightDeposit
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(IN_FLIGHT_DEPOSIT_SLOT, _newValue);
    }
}
