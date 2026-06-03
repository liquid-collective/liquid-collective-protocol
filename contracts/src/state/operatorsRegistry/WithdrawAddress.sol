//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title Withdraw Address Storage
/// @notice Utility to manage the Withdraw Address in storage
library WithdrawAddress {
    /// @notice Storage slot of the Withdraw Address
    bytes32 internal constant WITHDRAW_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.withdrawAddress")) - 1);

    /// @notice Retrieve the Withdraw Address
    /// @return The Withdraw Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(WITHDRAW_ADDRESS_SLOT);
    }

    /// @notice Sets the Withdraw Address
    /// @param _newValue New Withdraw Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(WITHDRAW_ADDRESS_SLOT, _newValue);
    }
}
