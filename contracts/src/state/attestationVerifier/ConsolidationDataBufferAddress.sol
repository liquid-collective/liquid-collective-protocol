//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title ConsolidationDataBufferAddress
/// @notice Library for storing the address of the ConsolidationDataBuffer contract.
library ConsolidationDataBufferAddress {
    bytes32 internal constant CONSOLIDATION_DATA_BUFFER_ADDRESS_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.consolidationDataBufferAddress")) - 1);

    /// @notice Retrieve the address of the ConsolidationDataBuffer contract
    /// @return The address of the ConsolidationDataBuffer contract
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(CONSOLIDATION_DATA_BUFFER_ADDRESS_SLOT);
    }

    /// @notice Set the address of the ConsolidationDataBuffer contract
    /// @param newValue The new address of the ConsolidationDataBuffer contract
    function set(address newValue) internal {
        LibSanitize._notZeroAddress(newValue);
        LibUnstructuredStorage.setStorageAddress(CONSOLIDATION_DATA_BUFFER_ADDRESS_SLOT, newValue);
    }
}
