//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library OperatorRewardsShare {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.operatorRewardsShare")) - 1) */
    bytes32 internal constant OPERATOR_REWARDS_SHARE_SLOT =
        hex"8b296ea79529153bb5bae302cb8c44db7ed739099e80c9f19feb68f6a43578a7";

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(OPERATOR_REWARDS_SHARE_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(OPERATOR_REWARDS_SHARE_SLOT, newValue);
    }
}
