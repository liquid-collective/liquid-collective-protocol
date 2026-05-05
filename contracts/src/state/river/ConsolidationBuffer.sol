//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

library ConsolidationBuffer {
    bytes32 internal constant CONSOLIDATION_BUFFER_SLOT =
        bytes32(uint256(keccak256("river.state.consolidationBuffer")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CONSOLIDATION_BUFFER_SLOT);
    }

    function set(uint256 _consolidationBuffer) internal {
        LibUnstructuredStorage.setStorageUint256(CONSOLIDATION_BUFFER_SLOT, _consolidationBuffer);
    }
}
