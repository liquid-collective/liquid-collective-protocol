//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

library EthToDeposit {
    bytes32 internal constant ETH_TO_DEPOSIT_SLOT = bytes32(uint256(keccak256("river.state.ethToDeposit")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(ETH_TO_DEPOSIT_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(ETH_TO_DEPOSIT_SLOT, newValue);
    }
}
