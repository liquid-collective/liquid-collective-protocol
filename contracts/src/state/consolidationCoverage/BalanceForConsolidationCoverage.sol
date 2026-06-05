//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Balance For Consolidation Coverage Value Storage
/// @notice Utility to manage the Balance For Consolidation Coverage value in storage
library BalanceForConsolidationCoverage {
    /// @notice Storage slot of the Balance For Consolidation Coverage
    bytes32 internal constant BALANCE_FOR_CONSOLIDATION_COVERAGE_SLOT =
        bytes32(uint256(keccak256("river.state.balanceForConsolidationCoverage")) - 1);

    /// @notice Get the Balance for Consolidation Coverage value
    /// @return The balance for consolidation coverage value
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(BALANCE_FOR_CONSOLIDATION_COVERAGE_SLOT);
    }

    /// @notice Sets the Balance for Consolidation Coverage value
    /// @param _newValue New Balance for Consolidation Coverage value
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(BALANCE_FOR_CONSOLIDATION_COVERAGE_SLOT, _newValue);
    }
}
