//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title OPWETH Address Storage
/// @notice Utility to manage the OPWETH Address in storage
library OPWETHAddress {
    /// @notice Storage slot of the OPWETH Address
    bytes32 internal constant OPWETH_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.opWETHAddress")) - 1);

    /// @notice Retrieve the OPWETH Address
    /// @return The OPWETH Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(OPWETH_ADDRESS_SLOT);
    }

    /// @notice Sets the OPWETH Address
    /// @param _newValue New OPWETH Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(OPWETH_ADDRESS_SLOT, _newValue);
    }
}
