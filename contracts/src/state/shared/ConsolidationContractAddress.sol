//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title Consolidation Contract Address Storage
/// @notice Utility to manage the Pectra EL consolidation contract address
library ConsolidationContractAddress {
    /// @notice Storage slot of the Consolidation Contract Address
    bytes32 internal constant CONSOLIDATION_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("withdraw.state.consolidationContractAddress")) - 1);

    /// @notice Retrieve the Consolidation Contract Address
    /// @return The Consolidation Contract Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(CONSOLIDATION_CONTRACT_ADDRESS_SLOT);
    }

    /// @notice Sets the Consolidation Contract Address
    /// @param _newValue New Consolidation Contract Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(CONSOLIDATION_CONTRACT_ADDRESS_SLOT, _newValue);
    }
}
