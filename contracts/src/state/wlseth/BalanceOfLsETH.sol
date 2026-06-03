//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Balance of LsETH Storage
/// @notice Utility to manage the Balance of LsETH in storage
library BalanceOfLsETH {
    /// @notice Storage slot of the Balance of LsETH
    bytes32 internal constant BALANCE_OF_LSETH_SLOT = bytes32(uint256(keccak256("river.state.balanceOfLsETH")) - 1);

    /// @notice Retrieve the balance of LsETH
    /// @return The balance of LsETH
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(BALANCE_OF_LSETH_SLOT);
    }

    /// @notice Set the balance of LsETH
    /// @param _newValue The new balance of LsETH
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(BALANCE_OF_LSETH_SLOT, _newValue);
    }
}
