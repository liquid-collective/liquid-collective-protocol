//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/// @title Consensus Layer Spec Storage
/// @notice Utility to manage the Consensus Layer Spec in storage
library CLSpec {
    /// @notice Storage slot of the Consensus Layer Spec
    bytes32 internal constant CL_SPEC_SLOT = bytes32(uint256(keccak256("river.state.clSpec")) - 1);

    /// @notice The Consensus Layer Spec structure
    struct CLSpecStruct {
        uint64 epochsPerFrame;
        uint64 slotsPerEpoch;
        uint64 secondsPerSlot;
        uint64 genesisTime;
    }

    /// @notice The structure in storage
    struct Slot {
        CLSpecStruct value;
    }

    /// @notice Retrieve the Consensus Layer Spec from storage
    /// @return The Consensus Layer Spec
    function get() internal view returns (CLSpecStruct memory) {
        bytes32 slot = CL_SPEC_SLOT;

        Slot storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value;
    }

    /// @notice Set the Consensus Layer Spec value in storage
    /// @param _newCLSpec The new value to set in storage
    function set(CLSpecStruct memory _newCLSpec) internal {
        bytes32 slot = CL_SPEC_SLOT;

        Slot storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value = _newCLSpec;
    }
}
