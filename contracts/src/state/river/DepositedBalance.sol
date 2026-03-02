//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Deposited Balance Storage
/// @notice Utility to manage the Deposited Balance in storage
library DepositedBalance {
    /// @notice Storage slot of the Deposited Balance
    bytes32 internal constant DEPOSITED_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.depositedBalance")) - 1);

    /// @notice Retrieve the Deposited Balance
    /// @return The Deposited Balance
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(DEPOSITED_BALANCE_SLOT);
    }

    /// @notice Sets the Deposited Balance
    /// @param _newValue New Deposited Balance
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(DEPOSITED_BALANCE_SLOT, _newValue);
    }
}
