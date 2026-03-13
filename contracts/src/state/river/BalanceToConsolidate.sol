//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

library BalanceToConsolidate {
    bytes32 internal constant BALANCE_TO_CONSOLIDATE_SLOT =
        bytes32(uint256(keccak256("river.state.balanceToConsolidate")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(BALANCE_TO_CONSOLIDATE_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(BALANCE_TO_CONSOLIDATE_SLOT, newValue);
    }
}
