//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title Bridge Address Storage
/// @notice Utility to manage the Bridge Address in storage
library BridgeAddress {
    /// @notice Storage slot of the Bridge Address
    bytes32 internal constant BRIDGE_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.bridgeAddress")) - 1);

    /// @notice Retrieve the Bridge Address
    /// @return The Bridge Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(BRIDGE_ADDRESS_SLOT);
    }

    /// @notice Sets the Bridge Address
    /// @param _newValue New Bridge Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(BRIDGE_ADDRESS_SLOT, _newValue);
    }
}
