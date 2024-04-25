//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title RemoteToken Address Storage
/// @notice Utility to manage the RemoteToken Address in storage
library RemoteTokenAddress {
    /// @notice Storage slot of the RemoteToken Address
    bytes32 internal constant REMOTETOKEN_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.remoteTokenAddress")) - 1);

    /// @notice Retrieve the RemoteToken Address
    /// @return The RemoteToken Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(REMOTETOKEN_ADDRESS_SLOT);
    }

    /// @notice Sets the RemoteToken Address
    /// @param _newValue New RemoteToken Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(REMOTETOKEN_ADDRESS_SLOT, _newValue);
    }
}
