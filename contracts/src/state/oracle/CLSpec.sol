//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library CLSpec {
    // Lido Finance cl spec data structure
    struct CLSpecStruct {
        uint64 epochsPerFrame;
        uint64 slotsPerEpoch;
        uint64 secondsPerSlot;
        uint64 genesisTime;
    }

    bytes32 internal constant CL_SPEC_SLOT = bytes32(uint256(keccak256("river.state.clSpec")) - 1);

    struct Slot {
        CLSpecStruct value;
    }

    function get() internal view returns (CLSpecStruct memory) {
        bytes32 slot = CL_SPEC_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(CLSpecStruct memory newCLSpec) internal {
        bytes32 slot = CL_SPEC_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newCLSpec;
    }
}
