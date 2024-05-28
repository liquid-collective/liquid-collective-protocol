//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title EigenStrategyManager Address Storage
/// @notice Utility to manage the EigenStrategyManager Address in storage
library EigenStrategyManagerAddress {
    /// @notice Storage slot of the EigenStrategyManager Address
    bytes32 internal constant EIGENSTRATEGYMANAGER_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.eigenStrategyManagerAddress")) - 1);

    /// @notice Retrieve the EigenStrategyManager Address
    /// @return The EigenStrategyManager Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(EIGENSTRATEGYMANAGER_ADDRESS_SLOT);
    }

    /// @notice Sets the EigenStrategyManager Address
    /// @param _newValue New EigenStrategyManager Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(EIGENSTRATEGYMANAGER_ADDRESS_SLOT, _newValue);
    }
}
