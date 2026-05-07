//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Consolidation Buffer tracks the amount of ETH(wei) that is reported while
///        minting LsETH due to external consolidation.
library ConsolidationBuffer {
    /// @notice Storage slot of the consolidation buffer
    bytes32 internal constant CONSOLIDATION_BUFFER_SLOT =
        bytes32(uint256(keccak256("river.state.consolidationBuffer")) - 1);

    /// @notice Retrieves the consolidation buffer from storage
    /// @return The consolidation buffer
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CONSOLIDATION_BUFFER_SLOT);
    }

    /// @notice Sets the consolidation buffer in storage
    /// @param _consolidationBuffer The new consolidation buffer value
    function set(uint256 _consolidationBuffer) internal {
        LibUnstructuredStorage.setStorageUint256(CONSOLIDATION_BUFFER_SLOT, _consolidationBuffer);
    }
}
