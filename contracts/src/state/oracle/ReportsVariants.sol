//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library ReportsVariants {
    uint256 internal constant COUNT_OUTMASK = 0xFFFFFFFFFFFFFFFFFFFFFFFF0000;

    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.reportsVariants")) - 1) */
    bytes32 internal constant REPORTS_VARIANTS_SLOT =
        hex"f1827321f6d023724a23b4e28f3ef67f741d185cff4e224f6dcbb56935784fcc";

    struct Slot {
        uint256[] value;
    }

    function get() internal view returns (uint256[] memory) {
        bytes32 slot = REPORTS_VARIANTS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(uint256 idx, uint256 val) internal {
        bytes32 slot = REPORTS_VARIANTS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value[idx] = val;
    }

    function push(uint256 variant) internal {
        bytes32 slot = REPORTS_VARIANTS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value.push(variant);
    }

    function indexOfReport(uint256 variant) internal view returns (int256) {
        bytes32 slot = REPORTS_VARIANTS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        for (uint256 idx = 0; idx < r.value.length; ++idx) {
            if (r.value[idx] & COUNT_OUTMASK == variant) {
                return int256(idx);
            }
        }

        return int256(-1);
    }

    function clear() internal {
        bytes32 slot = REPORTS_VARIANTS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        delete r.value;
    }
}
