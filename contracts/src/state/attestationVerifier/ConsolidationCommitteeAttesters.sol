//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title ConsolidationCommitteeAttesters
/// @notice Unstructured storage library for the consolidation-committee attester set and count.
///         Membership uses a slot-based mapping:
///         slot = keccak256(abi.encode(CONSOLIDATION_COMMITTEE_ATTESTER_MAPPING_BASE_SLOT, account))
library ConsolidationCommitteeAttesters {
    bytes32 internal constant CONSOLIDATION_COMMITTEE_ATTESTER_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.consolidationCommitteeAttesters.mapping")) - 1);

    bytes32 internal constant CONSOLIDATION_COMMITTEE_ATTESTER_COUNT_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.consolidationCommitteeAttesters.count")) - 1);

    /// @notice Check if an account is a consolidation-committee attester
    /// @param account The account to check
    /// @return True if the account is a consolidation-committee attester, false otherwise
    function isConsolidationCommitteeAttester(address account) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(CONSOLIDATION_COMMITTEE_ATTESTER_MAPPING_BASE_SLOT, account));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Set the consolidation-committee attester status for an account
    /// @param account The account to set
    /// @param value The new consolidation-committee attester status
    function setConsolidationCommitteeAttester(address account, bool value) internal {
        LibSanitize._notZeroAddress(account);
        bytes32 slot = keccak256(abi.encode(CONSOLIDATION_COMMITTEE_ATTESTER_MAPPING_BASE_SLOT, account));
        LibUnstructuredStorage.setStorageBool(slot, value);
    }

    /// @notice Retrieve the consolidation-committee attester count
    /// @return The consolidation-committee attester count
    function getCount() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CONSOLIDATION_COMMITTEE_ATTESTER_COUNT_SLOT);
    }

    /// @notice Set the consolidation-committee attester count
    /// @param count The new consolidation-committee attester count
    function setCount(uint256 count) internal {
        LibUnstructuredStorage.setStorageUint256(CONSOLIDATION_COMMITTEE_ATTESTER_COUNT_SLOT, count);
    }
}
