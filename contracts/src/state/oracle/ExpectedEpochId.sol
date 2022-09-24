//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

library ExpectedEpochId {
    bytes32 internal constant EXPECTED_EPOCH_ID_SLOT = bytes32(uint256(keccak256("river.state.expectedEpochId")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(EXPECTED_EPOCH_ID_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(EXPECTED_EPOCH_ID_SLOT, newValue);
    }
}
