//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

library ELFeeMaxPullBps {
    bytes32 internal constant EL_FEE_MAX_PULL_BPS_SLOT = bytes32(uint256(keccak256("river.state.elFeeMaxPullBps")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(EL_FEE_MAX_PULL_BPS_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(EL_FEE_MAX_PULL_BPS_SLOT, newValue);
    }
}
