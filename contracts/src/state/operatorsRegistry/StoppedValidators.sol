//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/// @title Stopped Validators Array Storage
/// @notice Utility to manage the Stopped Validators in storage
library StoppedValidators {
    /// @notice Storage slot of the Stopped Validators
    bytes32 internal constant STOPPED_VALIDATORS_SLOT = bytes32(uint256(keccak256("river.state.stoppedValidators")) - 1);

    struct Slot {
        uint32[] value;
    }

    /// @notice Retrieve the storage pointer of the Stopped Validators array
    /// @return The Stopped Validators storage pointer
    function get() internal view returns (uint32[] storage) {
        bytes32 slot = STOPPED_VALIDATORS_SLOT;

        Slot storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value;
    }

    /// @notice Sets the entire stopped validators array
    /// @param value The new stopped validators array
    function setRaw(uint32[] memory value) internal {
        bytes32 slot = STOPPED_VALIDATORS_SLOT;

        Slot storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value = value;
    }
}
