//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title River Deposit Manager Address Storage
/// @notice Utility to manage the RiverDepositManager address in River storage. The RiverDepositManager
///         holds the body of the attestation-gated consensus-layer deposit flow, which River reaches via
///         delegatecall, so it executes in River's storage context.
library RiverDepositManagerAddress {
    /// @notice Storage slot of the RiverDepositManager address
    bytes32 internal constant RIVER_DEPOSIT_MANAGER_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.riverDepositManagerAddress")) - 1);

    /// @notice Retrieve the RiverDepositManager address
    /// @return The RiverDepositManager address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(RIVER_DEPOSIT_MANAGER_ADDRESS_SLOT);
    }

    /// @notice Sets the RiverDepositManager address
    /// @param _newValue New RiverDepositManager address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(RIVER_DEPOSIT_MANAGER_ADDRESS_SLOT, _newValue);
    }
}
