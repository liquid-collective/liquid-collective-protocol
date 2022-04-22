//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library FunctionPermissionsContractAddress {
    bytes32 public constant FUNCTION_PERMISSIONS_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.functionPermissionsContractAddress")) - 1);

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(FUNCTION_PERMISSIONS_CONTRACT_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        UnstructuredStorage.setStorageAddress(FUNCTION_PERMISSIONS_CONTRACT_ADDRESS_SLOT, newValue);
    }
}
