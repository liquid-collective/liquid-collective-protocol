//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title AttestationThreshold
/// @notice Library for storing the attestation threshold.
library AttestationThreshold {
    bytes32 internal constant ATTESTATION_THRESHOLD_SLOT =
        bytes32(uint256(keccak256("river.state.attestationThreshold")) - 1);

    /// @notice Retrieve the attestation threshold
    /// @return The attestation threshold
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(ATTESTATION_THRESHOLD_SLOT);
    }

    /// @notice Set the attestation threshold
    /// @param newValue The new attestation threshold
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(ATTESTATION_THRESHOLD_SLOT, newValue);
    }
}
