//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library ExpectedEpochId {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.expectedEpochId")) - 1) */
    bytes32 internal constant EXPECTED_EPOCH_ID_SLOT =
        hex"45d0d54fdd66220435526b0d20a3e002dad71447d5a32fb8efce72e62d4e0227";

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(EXPECTED_EPOCH_ID_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(EXPECTED_EPOCH_ID_SLOT, newValue);
    }
}
