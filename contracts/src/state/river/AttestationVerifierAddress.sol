//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title Attestation Verifier Address Storage
/// @notice Utility to manage the AttestationVerifier address in River storage.
library AttestationVerifierAddress {
    /// @notice Storage slot of the AttestationVerifier address
    bytes32 internal constant ATTESTATION_VERIFIER_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.attestationVerifierAddress")) - 1);

    /// @notice Retrieve the AttestationVerifier address
    /// @return The AttestationVerifier address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(ATTESTATION_VERIFIER_ADDRESS_SLOT);
    }

    /// @notice Sets the AttestationVerifier address
    /// @param _newValue New AttestationVerifier address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(ATTESTATION_VERIFIER_ADDRESS_SLOT, _newValue);
    }
}
