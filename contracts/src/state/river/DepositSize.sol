//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Deposit Size
/// @author Alluvial Finance Inc.
/// @notice This library stores the deposit size for the River contract
library DepositSize {
    bytes32 internal constant DEPOSIT_SIZE = bytes32(uint256(keccak256("river.state.depositSize")) - 1);

    /// @notice Retrieve the deposit size
    /// @return The deposit size
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(DEPOSIT_SIZE);
    }

    /// @notice Set the deposit size
    /// @param newValue The new deposit size
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(DEPOSIT_SIZE, newValue);
    }
}
