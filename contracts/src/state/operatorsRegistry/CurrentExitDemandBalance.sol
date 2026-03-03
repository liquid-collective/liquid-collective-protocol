//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title CurrentExitDemandBalance Storage
/// @notice Tracks the total ETH amount of exit demand that has not yet been fulfilled by exit requests
library CurrentExitDemandBalance {
    bytes32 internal constant CURRENT_EXIT_DEMAND_BALANCE_SLOT =
        bytes32(uint256(keccak256("operatorsRegistry.state.currentExitDemandBalance")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CURRENT_EXIT_DEMAND_BALANCE_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(CURRENT_EXIT_DEMAND_BALANCE_SLOT, newValue);
    }
}
