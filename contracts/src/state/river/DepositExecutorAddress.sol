//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title Deposit Executor Address Storage
/// @notice Utility to manage the DepositExecutor address in River storage.
library DepositExecutorAddress {
    /// @notice Storage slot of the DepositExecutor address
    bytes32 internal constant DEPOSIT_EXECUTOR_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.depositExecutorAddress")) - 1);

    /// @notice Retrieve the DepositExecutor address
    /// @return The DepositExecutor address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(DEPOSIT_EXECUTOR_ADDRESS_SLOT);
    }

    /// @notice Sets the DepositExecutor address
    /// @param _newValue New DepositExecutor address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(DEPOSIT_EXECUTOR_ADDRESS_SLOT, _newValue);
    }
}
