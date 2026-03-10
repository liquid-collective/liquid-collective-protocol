//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

library InFlightETH {
    bytes32 internal constant IN_FLIGHT_ETH_SLOT = bytes32(uint256(keccak256("river.state.inFlightETH")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(IN_FLIGHT_ETH_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(IN_FLIGHT_ETH_SLOT, newValue);
    }
}
