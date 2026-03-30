//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

library DepositDataBufferAddress {
    bytes32 internal constant DEPOSIT_DATA_BUFFER_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.depositDataBufferAddress")) - 1);

    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(DEPOSIT_DATA_BUFFER_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        LibUnstructuredStorage.setStorageAddress(DEPOSIT_DATA_BUFFER_ADDRESS_SLOT, newValue);
    }
}
