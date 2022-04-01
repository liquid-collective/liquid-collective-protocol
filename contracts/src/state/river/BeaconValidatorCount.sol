//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library BeaconValidatorCount {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.beaconValidatorCount")) - 1) */
    bytes32 internal constant BEACON_VALIDATOR_COUNT_SLOT =
        hex"6929b6137e885d965ed089510659a629a29a4a54f85c28286fa5e0d7dcf27a36";

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(BEACON_VALIDATOR_COUNT_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(BEACON_VALIDATOR_COUNT_SLOT, newValue);
    }
}
