//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

// review(nmvlera): feels like we could reuse something like https://github.com/aragon/aragonOS/blob/next/contracts/common/UnstructuredStorage.sol
// that has methods to get/set whatever the stored base type is.
library Quorum {

    bytes32 public constant QUORUM_SLOT = bytes32(uint256(keccak256("river.state.quorum")) - 1);

    struct Slot {
        uint256 value;
    }

    function get() internal view returns (uint256) {
        bytes32 slot = QUORUM_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(uint256 newValue) internal {
        bytes32 slot = QUORUM_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newValue;
    }
}
