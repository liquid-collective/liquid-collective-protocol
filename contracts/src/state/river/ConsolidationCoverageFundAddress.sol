//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Consolidation Coverage Fund Address Storage
/// @notice Utility to manage the Consolidation Coverage Fund Address in storage
/// @notice The consolidation fund is optional; address zero is allowed (no fund configured)
library ConsolidationCoverageFundAddress {
    /// @notice Storage slot of the Consolidation Coverage Fund Address
    bytes32 internal constant CONSOLIDATION_COVERAGE_FUND_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.consolidationCoverageFundAddress")) - 1);

    /// @notice Retrieve the Consolidation Coverage Fund Address
    /// @return The Consolidation Coverage Fund Address (may be address(0))
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(CONSOLIDATION_COVERAGE_FUND_ADDRESS_SLOT);
    }

    /// @notice Sets the Consolidation Coverage Fund Address
    /// @param _newValue New Consolidation Coverage Fund Address (address(0) allowed to disable)
    function set(address _newValue) internal {
        LibUnstructuredStorage.setStorageAddress(CONSOLIDATION_COVERAGE_FUND_ADDRESS_SLOT, _newValue);
    }
}
