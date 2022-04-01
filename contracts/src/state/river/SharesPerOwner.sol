//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library SharesPerOwner {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.sharesPerOwner")) - 1) */
    bytes32 internal constant SHARES_SLOT = hex"0fb4a5ac9287f4f508aa7253ee2d57c6a228b1b30e210d73fffd59389d3a8837";

    struct Slot {
        mapping(address => uint256) value;
    }

    function get(address owner) internal view returns (uint256) {
        bytes32 slot = SHARES_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value[owner];
    }

    function set(address owner, uint256 newValue) internal {
        bytes32 slot = SHARES_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value[owner] = newValue;
    }
}
