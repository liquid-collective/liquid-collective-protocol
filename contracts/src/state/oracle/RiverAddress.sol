//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library RiverAddress {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.riverAddress")) - 1) */
    bytes32 internal constant RIVER_ADDRESS_SLOT = hex"1ec4138404500a2a0be2c2f9b103581c2a7fa783a934f91a6cc5cc924404973b";

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(RIVER_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        UnstructuredStorage.setStorageAddress(RIVER_ADDRESS_SLOT, newValue);
    }
}
