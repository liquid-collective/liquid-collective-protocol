//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library CLValidatorCount {
    bytes32 internal constant CL_VALIDATOR_COUNT_SLOT = bytes32(uint256(keccak256("river.state.clValidatorCount")) - 1);

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(CL_VALIDATOR_COUNT_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(CL_VALIDATOR_COUNT_SLOT, newValue);
    }
}
