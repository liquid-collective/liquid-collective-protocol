//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title EigenStrategy Address Storage
/// @notice Utility to manage the EigenStrategy Address in storage
library EigenStrategyAddress {
    /// @notice Storage slot of the EigenStrategy Address
    bytes32 internal constant EIGENSTRATEGY_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.eigenStrategyAddress")) - 1);

    /// @notice Retrieve the EigenStrategy Address
    /// @return The EigenStrategy Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(EIGENSTRATEGY_ADDRESS_SLOT);
    }

    /// @notice Sets the EigenStrategy Address
    /// @param _newValue New EigenStrategy Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(EIGENSTRATEGY_ADDRESS_SLOT, _newValue);
    }
}
