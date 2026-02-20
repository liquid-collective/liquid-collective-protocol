//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title CCIPAdmin Address Storage
/// @notice Utility to manage the CCIPAdmin Address in storage
library CCIPAdminAddress {
    /// @notice Storage slot of the CCIPAdmin Address
    bytes32 internal constant CCIP_ADMIN_ADDRESS_SLOT = bytes32(uint256(keccak256("state.ccipAdminAddress")) - 1);

    /// @notice Retrieve the CCIPAdmin Address
    /// @return The CCIPAdmin Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(CCIP_ADMIN_ADDRESS_SLOT);
    }

    /// @notice Sets the CCIPAdmin Address
    /// @param _newValue New CCIPAdmin Address
    function set(address _newValue) internal {
        LibUnstructuredStorage.setStorageAddress(CCIP_ADMIN_ADDRESS_SLOT, _newValue);
    }
}
