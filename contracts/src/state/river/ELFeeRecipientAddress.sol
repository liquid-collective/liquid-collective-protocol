//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

library ELFeeRecipientAddress {
    bytes32 internal constant EL_FEE_RECIPIENT_ADDRESS =
        bytes32(uint256(keccak256("river.state.elFeeRecipientAddress")) - 1);

    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(EL_FEE_RECIPIENT_ADDRESS);
    }

    function set(address newValue) internal {
        LibUnstructuredStorage.setStorageAddress(EL_FEE_RECIPIENT_ADDRESS, newValue);
    }
}
