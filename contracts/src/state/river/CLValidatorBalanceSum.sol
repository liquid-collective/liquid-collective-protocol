//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

library CLValidatorBalanceSum {
    bytes32 internal constant CL_VALIDATOR_BALANCE_SUM_SLOT =
        bytes32(uint256(keccak256("river.state.clValidatorBalanceSum")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CL_VALIDATOR_BALANCE_SUM_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(CL_VALIDATOR_BALANCE_SUM_SLOT, newValue);
    }
}
