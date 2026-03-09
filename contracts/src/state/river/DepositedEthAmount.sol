//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Deposited ETH Amount Storage
/// @notice Utility to manage the total ETH amount deposited to the consensus layer
library DepositedEthAmount {
    /// @notice Storage slot of the Deposited ETH Amount
    bytes32 internal constant DEPOSITED_ETH_AMOUNT_SLOT =
        bytes32(uint256(keccak256("river.state.depositedEthAmount")) - 1);

    /// @notice Retrieve the Deposited ETH Amount
    /// @return The Deposited ETH Amount
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(DEPOSITED_ETH_AMOUNT_SLOT);
    }

    /// @notice Sets the Deposited ETH Amount
    /// @param _newValue New Deposited ETH Amount
    function set(uint256 _newValue) internal {
        LibUnstructuredStorage.setStorageUint256(DEPOSITED_ETH_AMOUNT_SLOT, _newValue);
    }
}
