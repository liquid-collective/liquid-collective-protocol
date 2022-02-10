//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library RiverAddress {
    bytes32 public constant RIVER_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.riverAddress")) - 1);

    struct Slot {
        address value;
    }

    function get() internal view returns (address) {
        bytes32 slot = RIVER_ADDRESS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(address newValue) internal {
        bytes32 slot = RIVER_ADDRESS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newValue;
    }
}
