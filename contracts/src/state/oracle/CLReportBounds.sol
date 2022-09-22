//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library CLReportBounds {
    struct CLReportBoundsStruct {
        uint256 annualAprUpperBound;
        uint256 relativeLowerBound;
    }

    bytes32 internal constant CL_REPORT_BOUNDS_SLOT = bytes32(uint256(keccak256("river.state.clReportBounds")) - 1);

    struct Slot {
        CLReportBoundsStruct value;
    }

    function get() internal view returns (CLReportBoundsStruct memory) {
        bytes32 slot = CL_REPORT_BOUNDS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(CLReportBoundsStruct memory newCLReportBounds) internal {
        bytes32 slot = CL_REPORT_BOUNDS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newCLReportBounds;
    }
}
