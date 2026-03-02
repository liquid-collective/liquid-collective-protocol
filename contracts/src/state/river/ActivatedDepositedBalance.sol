//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Activated Deposited Balance Storage
/// @notice Utility to manage the Activated Deposited Balance in storage
library ActivatedDepositedBalance {
    /// @notice Storage slot of the Activated Deposited Balance
    bytes32 internal constant ACTIVATED_DEPOSITED_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.activatedDepositedBalance")) - 1);

    /// @notice Retrieve the Activated Deposited Balance
    /// @return The Activated Deposited Balance
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(ACTIVATED_DEPOSITED_BALANCE_SLOT);
    }

    /// @notice Sets the Activated Deposited Balance
    /// @param _newValue New Activated Deposited Balance
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(ACTIVATED_DEPOSITED_BALANCE_SLOT, _newValue);
    }
}
