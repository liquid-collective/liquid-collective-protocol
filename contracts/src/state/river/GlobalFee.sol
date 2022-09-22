//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

library GlobalFee {
    bytes32 internal constant GLOBAL_FEE_SLOT = bytes32(uint256(keccak256("river.state.globalFee")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(GLOBAL_FEE_SLOT);
    }

    function set(uint256 newValue) internal {
        LibSanitize._validFee(newValue);
        LibUnstructuredStorage.setStorageUint256(GLOBAL_FEE_SLOT, newValue);
    }
}
