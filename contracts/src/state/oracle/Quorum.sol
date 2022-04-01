//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library Quorum {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.quorum")) - 1) */
    bytes32 internal constant QUORUM_SLOT =
        hex"ffa4a5d927096d2bbb9d71111d7c9929ecbdcbe9bffc8d35f55b642e81698eba";

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(QUORUM_SLOT);
    }

    function set(uint256 newValue) internal {
        return UnstructuredStorage.setStorageUint256(QUORUM_SLOT, newValue);
    }
}
