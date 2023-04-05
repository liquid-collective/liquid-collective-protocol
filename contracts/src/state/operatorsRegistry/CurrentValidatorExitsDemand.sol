//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title CurrentValidatorExitsDemand Storage
/// @notice Utility to manage the CurrentValidatorExitsDemand in storage
library CurrentValidatorExitsDemand {
    /// @notice Storage slot of the CurrentValidatorExitsDemand
    bytes32 internal constant CURRENT_VALIDATOR_EXITS_DEMAND_SLOT =
        bytes32(uint256(keccak256("river.state.currentValidatorExitsDemand")) - 1);

    /// @notice Retrieve the CurrentValidatorExitsDemand
    /// @return The CurrentValidatorExitsDemand
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CURRENT_VALIDATOR_EXITS_DEMAND_SLOT);
    }

    /// @notice Sets the CurrentValidatorExitsDemand
    /// @param _newValue New CurrentValidatorExitsDemand
    function set(uint256 _newValue) internal {
        return LibUnstructuredStorage.setStorageUint256(CURRENT_VALIDATOR_EXITS_DEMAND_SLOT, _newValue);
    }
}
