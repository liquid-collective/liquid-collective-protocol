//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";
import "../../libraries/LibSanitize.sol";

/// @title LCWithdraw Address Storage
/// @notice Utility to manage the LCWithdraw Address in storage
library LCWithdrawAddress {
    /// @notice Storage slot of the LCWithdraw Address
    bytes32 internal constant LC_WITHDRAW_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.lcWithdrawAddress")) - 1);

    /// @notice Retrieve the LCWithdraw Address
    /// @return The LCWithdraw Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(LC_WITHDRAW_ADDRESS_SLOT);
    }

    /// @notice Sets the LCWithdraw Address
    /// @param _newValue New LCWithdraw Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(LC_WITHDRAW_ADDRESS_SLOT, _newValue);
    }
}
