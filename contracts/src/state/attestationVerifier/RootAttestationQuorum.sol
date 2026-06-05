//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title RootAttestationQuorum
/// @notice Library for storing the root attestation quorum.
library RootAttestationQuorum {
    bytes32 internal constant ROOT_ATTESTATION_QUORUM_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.rootAttestationQuorum")) - 1);

    /// @notice Retrieve the attestation quorum
    /// @return The attestation quorum
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(ROOT_ATTESTATION_QUORUM_SLOT);
    }

    /// @notice Set the attestation quorum
    /// @param newValue The new attestation quorum
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(ROOT_ATTESTATION_QUORUM_SLOT, newValue);
    }
}
