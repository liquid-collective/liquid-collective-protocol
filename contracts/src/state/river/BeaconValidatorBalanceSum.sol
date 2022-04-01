//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library BeaconValidatorBalanceSum {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.beaconValidatorBalanceSum")) - 1) */
    bytes32 internal constant VALIDATOR_BALANCE_SUM_SLOT =
        hex"42b27da24a254372d1e7ea692a34d85d9237abb39a65153affece1e2f1e608ff";

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(VALIDATOR_BALANCE_SUM_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(VALIDATOR_BALANCE_SUM_SLOT, newValue);
    }
}
