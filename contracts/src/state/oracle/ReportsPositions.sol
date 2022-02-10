//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library ReportsPositions {
    bytes32 public constant REPORTS_POSITIONS_SLOT = bytes32(uint256(keccak256("river.state.reportsPositions")) - 1);

    struct Slot {
        uint256 value;
    }

    function get(uint256 idx) internal view returns (bool) {
        bytes32 slot = REPORTS_POSITIONS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        uint256 mask = 1 << idx;

        return r.value & mask == 1;
    }

    function register(uint256 idx) internal {
        bytes32 slot = REPORTS_POSITIONS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        uint256 mask = 1 << idx;
        r.value = r.value | mask;
    }

    function clear() internal {
        bytes32 slot = REPORTS_POSITIONS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = 0;
    }
}
