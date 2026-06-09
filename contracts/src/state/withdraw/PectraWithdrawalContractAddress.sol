//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title Pectra Withdrawal Contract Address Storage
/// @notice Utility to manage the Pectra EL withdrawal contract address
library PectraWithdrawalContractAddress {
    /// @notice Storage slot of the Pectra Withdrawal Contract Address
    bytes32 internal constant PECTRA_WITHDRAWAL_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("withdraw.state.pectraWithdrawalContractAddress")) - 1);

    /// @notice Retrieve the Pectra Withdrawal Contract Address
    /// @return The Pectra Withdrawal Contract Address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(PECTRA_WITHDRAWAL_CONTRACT_ADDRESS_SLOT);
    }

    /// @notice Sets the Pectra Withdrawal Contract Address
    /// @param _newValue New Pectra Withdrawal Contract Address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(PECTRA_WITHDRAWAL_CONTRACT_ADDRESS_SLOT, _newValue);
    }
}
