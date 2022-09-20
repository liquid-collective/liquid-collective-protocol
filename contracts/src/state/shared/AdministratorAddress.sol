//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

library AdministratorAddress {
    bytes32 public constant ADMINISTRATOR_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.administratorAddress")) - 1);

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(ADMINISTRATOR_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        LibSanitize._notZeroAddress(newValue);
        UnstructuredStorage.setStorageAddress(ADMINISTRATOR_ADDRESS_SLOT, newValue);
    }
}
