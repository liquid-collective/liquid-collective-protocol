//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title TotalDepositedETH Storage
/// @notice This value is the total deposited ETH
/// @notice Utility to manage the TotalDepositedETH in storage
library TotalDepositedETH {
    bytes32 internal constant TOTAL_DEPOSITED_ETH_SLOT = bytes32(uint256(keccak256("river.state.totalDepositedETH")) - 1);

    /// @notice Retrieve the TotalDepositedETH
    /// @return The TotalDepositedETH
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(TOTAL_DEPOSITED_ETH_SLOT);
    }

    /// @notice Sets the TotalDepositedETH
    /// @param newValue New TotalDepositedETH
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(TOTAL_DEPOSITED_ETH_SLOT, newValue);
    }
}
