//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library GovernorAddress {
    bytes32 public constant GOVERNOR_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.governorAddress")) - 1);

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(GOVERNOR_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        UnstructuredStorage.setStorageAddress(GOVERNOR_ADDRESS_SLOT, newValue);
    }
}
