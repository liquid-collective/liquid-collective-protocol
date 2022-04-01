//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library BeaconSpec {
    // Lido Finance beacon spec data structure
    struct BeaconSpecStruct {
        uint64 epochsPerFrame;
        uint64 slotsPerEpoch;
        uint64 secondsPerSlot;
        uint64 genesisTime;
    }

    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.beaconSpec")) - 1) */
    bytes32 internal constant BEACON_SPEC_SLOT = hex"910cad6638f0b06b72ead1455bffc33be6e9b1c24417cc3f692aaaf0bef75a15";

    struct Slot {
        BeaconSpecStruct value;
    }

    function get() internal view returns (BeaconSpecStruct memory) {
        bytes32 slot = BEACON_SPEC_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(BeaconSpecStruct memory newBeaconSpec) internal {
        bytes32 slot = BEACON_SPEC_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newBeaconSpec;
    }
}
