//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Consensus Layer Validator Total Skimmed Balance Storage
/// @notice Utility to manage the Consensus Layer Validator Total Skimmed Balance in storage
library CLValidatorTotalSkimmedBalance {
    /// @notice Storage slot of the Consensus Layer Validator Total Skimmed Balance
    bytes32 internal constant CL_VALIDATOR_TOTAL_SKIMMED_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.clValidatorTotalSkimmed Balance")) - 1);

    /// @notice Retrieve the Consensus Layer Validator Total Skimmed Balance
    /// @return The Consensus Layer Validator Total Skimmed Balance
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CL_VALIDATOR_TOTAL_SKIMMED_BALANCE_SLOT);
    }

    /// @notice Sets the Consensus Layer Validator Total Skimmed Balance
    /// @param _newValue New Consensus Layer Validator Total SKimmed Balance
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(CL_VALIDATOR_TOTAL_SKIMMED_BALANCE_SLOT, _newValue);
    }
}
