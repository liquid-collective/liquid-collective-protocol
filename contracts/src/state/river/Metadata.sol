//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/// @title Metadata Storage
/// @notice Utility to manage the Metadata in storage
library Metadata {
    /// @notice Storage slot of the Metadata
    bytes32 internal constant METADATA_SLOT = bytes32(uint256(keccak256("river.state.metadata")) - 1);

    /// @notice Structure in storage
    struct Slot {
        /// @custom:attribute The metadata value
        string value;
    }

    /// @notice Retrieve the metadata
    /// @return The metadata string
    function get() internal view returns (string memory) {
        bytes32 slot = METADATA_SLOT;

        Slot storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value;
    }

    /// @notice Set the metadata value
    /// @param _newValue The new metadata value
    function set(string memory _newValue) internal {
        bytes32 slot = METADATA_SLOT;

        Slot storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value = _newValue;
    }
}
