//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

library CollectorAddress {
    bytes32 internal constant COLLECTOR_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.collectorAddress")) - 1);

    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(COLLECTOR_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        LibSanitize._notZeroAddress(newValue);
        LibUnstructuredStorage.setStorageAddress(COLLECTOR_ADDRESS_SLOT, newValue);
    }
}
