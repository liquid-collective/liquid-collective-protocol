//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title InFlightDepositBalance Storage
/// @notice Tracks the total ETH amount deposited to the consensus layer but not yet reported as active by the oracle
library InFlightDepositBalance {
    bytes32 internal constant IN_FLIGHT_DEPOSIT_BALANCE_SLOT =
        bytes32(uint256(keccak256("river.state.inFlightDepositBalance")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(IN_FLIGHT_DEPOSIT_BALANCE_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(IN_FLIGHT_DEPOSIT_BALANCE_SLOT, newValue);
    }
}
