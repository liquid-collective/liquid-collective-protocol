//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title ConsolidationCommitteeAttestationQuorum
/// @notice Library for storing the consolidation-committee attestation quorum.
library ConsolidationCommitteeAttestationQuorum {
    bytes32 internal constant CONSOLIDATION_COMMITTEE_ATTESTATION_QUORUM_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.consolidationCommitteeAttestationQuorum")) - 1);

    /// @notice Retrieve the attestation quorum
    /// @return The attestation quorum
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(CONSOLIDATION_COMMITTEE_ATTESTATION_QUORUM_SLOT);
    }

    /// @notice Set the attestation quorum
    /// @param newValue The new attestation quorum
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(CONSOLIDATION_COMMITTEE_ATTESTATION_QUORUM_SLOT, newValue);
    }
}
