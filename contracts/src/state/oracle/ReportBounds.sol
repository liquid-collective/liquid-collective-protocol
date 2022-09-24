//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library ReportBounds {
    struct ReportBoundsStruct {
        uint256 annualAprUpperBound;
        uint256 relativeLowerBound;
    }

    bytes32 internal constant REPORT_BOUNDS_SLOT = bytes32(uint256(keccak256("river.state.reportBounds")) - 1);

    struct Slot {
        ReportBoundsStruct value;
    }

    function get() internal view returns (ReportBoundsStruct memory) {
        bytes32 slot = REPORT_BOUNDS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(ReportBoundsStruct memory newReportBounds) internal {
        bytes32 slot = REPORT_BOUNDS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newReportBounds;
    }
}
