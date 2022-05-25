//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library TotalSupply {
    bytes32 internal constant TOTAL_SUPPLY_SLOT = bytes32(uint256(keccak256("river.state.totalSupply")) - 1);

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(TOTAL_SUPPLY_SLOT);
    }

    function set(uint256 newValue) internal {
        return UnstructuredStorage.setStorageUint256(TOTAL_SUPPLY_SLOT, newValue);
    }
}
