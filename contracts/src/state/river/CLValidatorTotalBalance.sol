//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

library CLValidatorTotalBalance {
    bytes32 internal constant CL_VALIDATOR_TOTAL_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.clValidatorTotalBalance")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CL_VALIDATOR_TOTAL_BALANCE_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(CL_VALIDATOR_TOTAL_BALANCE_SLOT, newValue);
    }
}
