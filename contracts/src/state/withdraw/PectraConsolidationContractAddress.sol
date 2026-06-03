//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title Pectra Consolidation Contract Address Storage
/// @notice Utility to manage the Pectra EL consolidation contract address
library PectraConsolidationContractAddress {
    /// @notice Storage slot of the Pectra Consolidation Contract Address
    bytes32 internal constant PECTRA_CONSOLIDATION_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("withdraw.state.pectraConsolidationContractAddress")) - 1);

    /// @notice Retrieve the Pectra Consolidation Contract Address
    /// @return The Pectra Consolidation Contract Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(PECTRA_CONSOLIDATION_CONTRACT_ADDRESS_SLOT);
    }

    /// @notice Sets the Pectra Consolidation Contract Address
    /// @param _newValue New Pectra Consolidation Contract Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(PECTRA_CONSOLIDATION_CONTRACT_ADDRESS_SLOT, _newValue);
    }
}
