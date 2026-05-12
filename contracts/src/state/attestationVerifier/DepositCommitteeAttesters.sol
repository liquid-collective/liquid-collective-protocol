//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title DepositCommitteeAttesters
/// @notice Unstructured storage library for the deposit-committee attester set and count.
///         Membership uses a slot-based mapping:
///         slot = keccak256(abi.encode(DEPOSIT_COMMITTEE_ATTESTER_MAPPING_BASE_SLOT, account))
library DepositCommitteeAttesters {
    bytes32 internal constant DEPOSIT_COMMITTEE_ATTESTER_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.depositCommitteeAttesters.mapping")) - 1);

    bytes32 internal constant DEPOSIT_COMMITTEE_ATTESTER_COUNT_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.depositCommitteeAttesters.count")) - 1);

    /// @notice Check if an account is a deposit-committee attester
    /// @param account The account to check
    /// @return True if the account is a deposit-committee attester, false otherwise
    function isDepositCommitteeAttester(address account) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(DEPOSIT_COMMITTEE_ATTESTER_MAPPING_BASE_SLOT, account));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Set the deposit-committee attester status for an account
    /// @param account The account to set
    /// @param value The new deposit-committee attester status
    function setDepositCommitteeAttester(address account, bool value) internal {
        bytes32 slot = keccak256(abi.encode(DEPOSIT_COMMITTEE_ATTESTER_MAPPING_BASE_SLOT, account));
        LibUnstructuredStorage.setStorageBool(slot, value);
    }

    /// @notice Retrieve the deposit-committee attester count
    /// @return The deposit-committee attester count
    function getCount() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(DEPOSIT_COMMITTEE_ATTESTER_COUNT_SLOT);
    }

    /// @notice Set the deposit-committee attester count
    /// @param count The new deposit-committee attester count
    function setCount(uint256 count) internal {
        LibUnstructuredStorage.setStorageUint256(DEPOSIT_COMMITTEE_ATTESTER_COUNT_SLOT, count);
    }
}
