//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library DepositedValidatorCount {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.depositedValidatorCount")) - 1) */
    bytes32 internal constant DEPOSITED_VALIDATOR_COUNT_SLOT =
        hex"c77078e3530c08cdb2440817c81de4836500b4708ea4d15672b7fe98956423a7";

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(DEPOSITED_VALIDATOR_COUNT_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(DEPOSITED_VALIDATOR_COUNT_SLOT, newValue);
    }
}
