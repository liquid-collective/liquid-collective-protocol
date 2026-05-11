//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title ValidatorDepositContractAddress
/// @notice Library for storing the address of the official ETH deposit contract,
///         used by the AttestationVerifier to read `get_deposit_root()` for the
///         front-run-resistant root-hash check.
/// @dev River keeps its own copy of the deposit-contract address for executing
///      `deposit{value:}()` calls. Both copies MUST point at the same address.
///      Library identifier is prefixed with `Validator` so it does not collide with
///      River's `DepositContractAddress` library when both contracts are pulled in
///      by the same compilation unit (e.g. tests).
library ValidatorDepositContractAddress {
    bytes32 internal constant DEPOSIT_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.depositContractAddress")) - 1);

    /// @notice Retrieve the deposit contract address
    /// @return The deposit contract address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(DEPOSIT_CONTRACT_ADDRESS_SLOT);
    }

    /// @notice Set the deposit contract address
    /// @param newValue The new deposit contract address
    function set(address newValue) internal {
        LibSanitize._notZeroAddress(newValue);
        LibUnstructuredStorage.setStorageAddress(DEPOSIT_CONTRACT_ADDRESS_SLOT, newValue);
    }
}
