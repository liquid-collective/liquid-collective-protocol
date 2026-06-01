//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Redeem Manager Rate Lock Demand storage
/// @notice LsETH amount still waiting for inactive-rate coverage
library RateLockDemand {
    bytes32 internal constant RATE_LOCK_DEMAND_SLOT = bytes32(uint256(keccak256("river.state.rateLockDemand")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(RATE_LOCK_DEMAND_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(RATE_LOCK_DEMAND_SLOT, newValue);
    }
}
