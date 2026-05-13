//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title DepositDataBufferAddress
/// @notice Library for storing the address of the DepositDataBuffer contract.
library DepositDataBufferAddress {
    bytes32 internal constant DEPOSIT_DATA_BUFFER_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.depositDataBufferAddress")) - 1);

    /// @notice Retrieve the address of the DepositDataBuffer contract
    /// @return The address of the DepositDataBuffer contract
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(DEPOSIT_DATA_BUFFER_ADDRESS_SLOT);
    }

    /// @notice Set the address of the DepositDataBuffer contract
    /// @param newValue The new address of the DepositDataBuffer contract
    function set(address newValue) internal {
        LibUnstructuredStorage.setStorageAddress(DEPOSIT_DATA_BUFFER_ADDRESS_SLOT, newValue);
    }
}
