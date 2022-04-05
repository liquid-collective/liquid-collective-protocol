//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library AllowerAddress {
    bytes32 internal constant ALLOWER_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.allowerAddress")) - 1);

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(ALLOWER_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        UnstructuredStorage.setStorageAddress(ALLOWER_ADDRESS_SLOT, newValue);
    }
}
