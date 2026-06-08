//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title RootAttesters
/// @notice Unstructured storage library for the root attester set and count.
///         Membership uses a slot-based mapping:
///         slot = keccak256(abi.encode(ROOT_ATTESTERS_MAPPING_BASE_SLOT, account))
library RootAttesters {
    bytes32 internal constant ROOT_ATTESTERS_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.rootAttesters.mapping")) - 1);

    bytes32 internal constant ROOT_ATTESTERS_COUNT_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.rootAttesters.count")) - 1);

    /// @notice Check if an account is a root attester
    /// @param account The account to check
    /// @return True if the account is a root attester, false otherwise
    function isRootAttester(address account) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(ROOT_ATTESTERS_MAPPING_BASE_SLOT, account));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Set the root attester status for an account
    /// @param account The account to set
    /// @param value The new root attester status
    function setRootAttester(address account, bool value) internal {
        LibSanitize._notZeroAddress(account);
        bytes32 slot = keccak256(abi.encode(ROOT_ATTESTERS_MAPPING_BASE_SLOT, account));
        LibUnstructuredStorage.setStorageBool(slot, value);
    }

    /// @notice Retrieve the root attester count
    /// @return The root attester count
    function getCount() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(ROOT_ATTESTERS_COUNT_SLOT);
    }

    /// @notice Set the root attester count
    /// @param count The new root attester count
    function setCount(uint256 count) internal {
        LibUnstructuredStorage.setStorageUint256(ROOT_ATTESTERS_COUNT_SLOT, count);
    }
}
