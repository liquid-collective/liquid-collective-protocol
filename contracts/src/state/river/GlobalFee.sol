//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library GlobalFee {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.globalFee")) - 1) */
    bytes32 internal constant GLOBAL_FEE_SLOT = hex"094efef62d2ce60c14ffacd35a1b50546d3a9d503aff1df040176fffd6c92a36";

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(GLOBAL_FEE_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(GLOBAL_FEE_SLOT, newValue);
    }
}
