//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library BeaconReportBounds {
    // Lido Finance beacon spec data structure
    struct BeaconReportBoundsStruct {
        uint256 annualAprUpperBound;
        uint256 relativeLowerBound;
    }

    uint256 public constant DELTA_BASE = 10_000;

    // review(nmvalera): major
    // Can we split the constant storage from the function logic? So we increase reusability
    // For example could we create a stateless library libraries/storage/EpochStorage.sol that implements get(self) and set(self, ...) similarly to https://github.com/aragon/aragonOS/blob/next/contracts/common/UnstructuredStorage.sol? 
    // Then a contract that needs to use an BeaconReportBoundsStorage could import it and do something like (not sure it is possible):

    // BeaconReportBoundsStorage public constant ... = bytes32(uint256(keccak256(...)) - 1);

    // review(nmvalera): medium
    // Could we hard code the hex instead of calling bytes32(uint256(keccak256(...)) - 1)? It should save some gas at deployment
    // Example: https://github.com/aragon/aragonOS/blob/next/contracts/apps/AppStorage.sol#L15

    // review(nmvalera): minor
    // Rename constant field *_SSLOT instead of *_SLOT to avoid confusing between Eth2.0 slot and storage slot 
    bytes32 public constant BEACON_REPORT_BOUNDS_SLOT =
        bytes32(uint256(keccak256("river.state.beaconReportBounds")) - 1);

    // review(nmvalera): major: do we absolutly need the intermediary Slot struct or could we manage? Or could we manage only through mload/mstore (found this: https://ethereum.stackexchange.com/questions/87975/sload-assembly-with-struct-not-working-in-solidity) It is likely more gas efficient
    struct Slot {
        BeaconReportBoundsStruct value;
    }

    function get() internal view returns (BeaconReportBoundsStruct memory) {
        bytes32 slot = BEACON_REPORT_BOUNDS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(BeaconReportBoundsStruct memory newBeaconReportBounds) internal {
        bytes32 slot = BEACON_REPORT_BOUNDS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newBeaconReportBounds;
    }
}
