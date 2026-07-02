//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title Consolidator Address Storage
/// @notice Utility to manage the Consolidator Address in storage
library ConsolidatorAddress {
    /// @notice Storage slot of the Consolidator Address
    bytes32 internal constant CONSOLIDATOR_ADDRESS_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.consolidatorAddress")) - 1);

    /// @notice Retrieve the Consolidator Address
    /// @return The Consolidator Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(CONSOLIDATOR_ADDRESS_SLOT);
    }

    /// @notice Sets the Consolidator Address
    /// @param _newValue New Consolidator Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(CONSOLIDATOR_ADDRESS_SLOT, _newValue);
    }
}
