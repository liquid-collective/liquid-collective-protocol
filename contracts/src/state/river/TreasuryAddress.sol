//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library TreasuryAddress {
    bytes32 public constant TREASURY_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.treasuryAddress")) - 1);

    struct Slot {
        address value;
    }

    function get() internal view returns (address) {
        bytes32 slot = TREASURY_ADDRESS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(address newTreasury) internal {
        bytes32 slot = TREASURY_ADDRESS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newTreasury;
    }
}
