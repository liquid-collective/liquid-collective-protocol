//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title Consolidation Coverage Fund Address Storage
/// @notice Utility to manage the Consolidation Coverage Fund Address in storage
/// @notice Address zero is not allowed
library ConsolidationCoverageFundAddress {
    /// @notice Storage slot of the Consolidation Coverage Fund Address
    bytes32 internal constant CONSOLIDATION_COVERAGE_FUND_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.consolidationCoverageFundAddress")) - 1);

    /// @notice Retrieve the Consolidation Coverage Fund Address
    /// @return The Consolidation Coverage Fund Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(CONSOLIDATION_COVERAGE_FUND_ADDRESS_SLOT);
    }

    /// @notice Sets the Consolidation Coverage Fund Address
    /// @param _newValue New Consolidation Coverage Fund Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(CONSOLIDATION_COVERAGE_FUND_ADDRESS_SLOT, _newValue);
    }
}
