//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library LastEpochId {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.lastEpochId")) - 1) */
    bytes32 internal constant LAST_EPOCH_ID_SLOT =
        hex"af3d74d3b4106d19ea8994739c1a66b48922195975ea284f4cd201487a79b9ec";

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(LAST_EPOCH_ID_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(LAST_EPOCH_ID_SLOT, newValue);
    }
}
