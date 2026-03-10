//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

library TotalDepositedETH {
    bytes32 internal constant TOTAL_DEPOSITED_ETH_SLOT = bytes32(uint256(keccak256("river.state.totalDepositedETH")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(TOTAL_DEPOSITED_ETH_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(TOTAL_DEPOSITED_ETH_SLOT, newValue);
    }
}
