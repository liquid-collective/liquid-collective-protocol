//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library BeaconValidatorCount {
    bytes32 public constant VALIDATOR_COUNT_SLOT = bytes32(uint256(keccak256("river.state.beaconValidatorCount")) - 1);

    struct Slot {
        uint256 value;
    }

    function get() internal view returns (uint256) {
        bytes32 slot = VALIDATOR_COUNT_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(uint256 newValue) internal {
        bytes32 slot = VALIDATOR_COUNT_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newValue;
    }
}
