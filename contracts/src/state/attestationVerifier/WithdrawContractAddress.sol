//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title WithdrawContractAddress
/// @notice Library for storing the address of the Withdraw contract.
library WithdrawContractAddress {
    bytes32 internal constant WITHDRAW_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.withdrawContractAddress")) - 1);

    /// @notice Retrieve the address of the Withdraw contract
    /// @return The address of the Withdraw contract
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(WITHDRAW_CONTRACT_ADDRESS_SLOT);
    }

    /// @notice Set the address of the Withdraw contract
    /// @param newValue The new address of the Withdraw contract
    function set(address newValue) internal {
        LibSanitize._notZeroAddress(newValue);
        LibUnstructuredStorage.setStorageAddress(WITHDRAW_CONTRACT_ADDRESS_SLOT, newValue);
    }
}
