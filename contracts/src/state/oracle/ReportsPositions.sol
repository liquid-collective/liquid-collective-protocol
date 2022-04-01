//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library ReportsPositions {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.reportsPositions")) - 1) */
    bytes32 internal constant REPORTS_POSITIONS_SLOT =
        hex"50e65b39a6b6b7bb3298d9d19e41cecec530b7916ba516c44f4d79e3a9dcd7a6";

    function get(uint256 idx) internal view returns (bool) {
        uint256 mask = 1 << idx;
        return UnstructuredStorage.getStorageUint256(REPORTS_POSITIONS_SLOT) & mask == mask;
    }

    function getRaw() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(REPORTS_POSITIONS_SLOT);
    }

    function register(uint256 idx) internal {
        uint256 mask = 1 << idx;
        return
            UnstructuredStorage.setStorageUint256(
                REPORTS_POSITIONS_SLOT,
                UnstructuredStorage.getStorageUint256(REPORTS_POSITIONS_SLOT) | mask
            );
    }

    function clear() internal {
        return UnstructuredStorage.setStorageUint256(REPORTS_POSITIONS_SLOT, 0);
    }
}
