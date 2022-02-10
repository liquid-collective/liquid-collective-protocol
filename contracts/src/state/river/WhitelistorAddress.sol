//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library WhitelistorAddress {
    bytes32 public constant WHITELISTOR_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.whitelistorAddress")) - 1);

    struct Slot {
        address value;
    }

    function get() internal view returns (address) {
        bytes32 slot = WHITELISTOR_ADDRESS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(address newValue) internal {
        bytes32 slot = WHITELISTOR_ADDRESS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newValue;
    }
}
