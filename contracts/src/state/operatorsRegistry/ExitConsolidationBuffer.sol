//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title ExitConsolidationBuffer Storage
/// @notice This value is the amount of performed exit requests, only increased when there is current exit demand
/// @notice Utility to manage the ExitConsolidationBuffer in storage
/// @dev This value is in ETH(wei)
library ExitConsolidationBuffer {
    /// @notice Storage slot of the ExitConsolidationBuffer
    bytes32 internal constant EXIT_CONSOLIDATION_BUFFER_SLOT =
        bytes32(uint256(keccak256("river.state.exitConsolidationBuffer")) - 1);

    /// @notice Retrieve the ExitConsolidationBuffer
    /// @return The ExitConsolidationBuffer
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(EXIT_CONSOLIDATION_BUFFER_SLOT);
    }

    /// @notice Sets the ExitConsolidationBuffer
    /// @param _newValue New ExitConsolidationBuffer
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(EXIT_CONSOLIDATION_BUFFER_SLOT, _newValue);
    }
}
