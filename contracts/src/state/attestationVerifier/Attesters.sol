//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Attesters
/// @notice Unstructured storage library for the attester set and count.
///         Attester membership uses a slot-based mapping:
///         slot = keccak256(abi.encode(ATTESTER_MAPPING_BASE_SLOT, account))
library Attesters {
    bytes32 internal constant ATTESTER_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.attesters.mapping")) - 1);

    bytes32 internal constant ATTESTER_COUNT_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.attesters.count")) - 1);

    /// @notice Check if an account is an attester
    /// @param account The account to check
    /// @return True if the account is an attester, false otherwise
    function isAttester(address account) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(ATTESTER_MAPPING_BASE_SLOT, account));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Set the attester status for an account
    /// @param account The account to set
    /// @param value The new attester status
    function setAttester(address account, bool value) internal {
        bytes32 slot = keccak256(abi.encode(ATTESTER_MAPPING_BASE_SLOT, account));
        LibUnstructuredStorage.setStorageBool(slot, value);
    }

    /// @notice Retrieve the attester count
    /// @return The attester count
    function getCount() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(ATTESTER_COUNT_SLOT);
    }

    /// @notice Set the attester count
    /// @param count The new attester count
    function setCount(uint256 count) internal {
        LibUnstructuredStorage.setStorageUint256(ATTESTER_COUNT_SLOT, count);
    }
}
