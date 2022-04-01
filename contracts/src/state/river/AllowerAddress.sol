//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library AllowerAddress {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.allowerAddress")) - 1) */
    bytes32 internal constant ALLOWER_ADDRESS_SLOT =
        hex"3d8762f71ac4675044de4231ebed7df0f8a8819893c6b6278d0461fc4a979b7f";

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(ALLOWER_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        UnstructuredStorage.setStorageAddress(ALLOWER_ADDRESS_SLOT, newValue);
    }
}
