//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title Withdrawal Contract Address Storage
/// @notice Utility to manage the Pectra EL withdrawal contract address
library WithdrawalContractAddress {
    /// @notice Storage slot of the Withdrawal Contract Address
    bytes32 internal constant WITHDRAWAL_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("withdraw.state.withdrawalContractAddress")) - 1);

    /// @notice Retrieve the Withdrawal Contract Address
    /// @return The Withdrawal Contract Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(WITHDRAWAL_CONTRACT_ADDRESS_SLOT);
    }

    /// @notice Sets the Withdrawal Contract Address
    /// @param _newValue New Withdrawal Contract Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(WITHDRAWAL_CONTRACT_ADDRESS_SLOT, _newValue);
    }
}
