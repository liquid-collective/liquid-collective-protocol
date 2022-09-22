//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibErrors.sol";

library RiverAddress {
    bytes32 internal constant RIVER_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.riverAddress")) - 1);

    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(RIVER_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        LibSanitize._notZeroAddress(newValue);
        LibUnstructuredStorage.setStorageAddress(RIVER_ADDRESS_SLOT, newValue);
    }
}
