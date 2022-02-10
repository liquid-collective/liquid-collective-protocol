//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library ExpectedEpochId {
    bytes32 public constant EXPECTED_EPOCH_ID_SLOT = bytes32(uint256(keccak256("river.state.expectedEpochId")) - 1);

    struct Slot {
        uint256 value;
    }

    function get() internal view returns (uint256) {
        bytes32 slot = EXPECTED_EPOCH_ID_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(uint256 newValue) internal {
        bytes32 slot = EXPECTED_EPOCH_ID_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newValue;
    }
}
