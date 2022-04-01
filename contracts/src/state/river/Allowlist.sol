//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library Allowlist {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.allowlist")) - 1) */
    bytes32 internal constant ALLOWLIST_SLOT = hex"f13551d5cf1b23afc8669eb5ef15070e351923179334eb1a5aa569477f4a4134";

    struct Slot {
        mapping(address => bool) value;
    }

    function get(address account) internal view returns (bool) {
        bytes32 slot = ALLOWLIST_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value[account];
    }

    function set(address account, bool status) internal {
        bytes32 slot = ALLOWLIST_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value[account] = status;
    }
}
