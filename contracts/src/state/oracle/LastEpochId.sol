//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library LastEpochId {
    // review(nmvalera): major
    // Can we split the constant storage from the function logic? So we increase reusability (avoiding to have both LastEpochId and ExpectedEpochId)
    // For example could we create a stateless library libraries/storage/EpochStorage.sol that implements get(self) and set(self, value) similarly to https://github.com/aragon/aragonOS/blob/next/contracts/common/UnstructuredStorage.sol? 
    // Then a contract that needs to use an EpochStorage could import it and do something like (not sure it is possible):

    // EpochStorage public constant LAST_EPOCH_ID_SLOT = bytes32(uint256(keccak256("river.state.lastEpochId")) - 1);

    // review(nmvalera): medium
    // Could we hard code the hex instead of calling bytes32(uint256(keccak256(...)) - 1)? It should save some gas at deployment
    // Example: https://github.com/aragon/aragonOS/blob/next/contracts/apps/AppStorage.sol#L15

    // review(nmvalera): minor
    // Rename constant field *_SSLOT instead of *_SLOT to avoid confusing between Eth2.0 slot and storage slot 
    bytes32 public constant LAST_EPOCH_ID_SLOT = bytes32(uint256(keccak256("river.state.lastEpochId")) - 1);

    struct Slot {
        uint256 value;
    }

    function get() internal view returns (uint256) {
        bytes32 slot = LAST_EPOCH_ID_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(uint256 newValue) internal {
        bytes32 slot = LAST_EPOCH_ID_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newValue;
    }
}
