//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title Attestation Validator Address Storage
/// @notice Utility to manage the AttestationValidator address in River storage.
library AttestationValidatorAddress {
    /// @notice Storage slot of the AttestationValidator address
    bytes32 internal constant ATTESTATION_VALIDATOR_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.attestationValidatorAddress")) - 1);

    /// @notice Retrieve the AttestationValidator address
    /// @return The AttestationValidator address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(ATTESTATION_VALIDATOR_ADDRESS_SLOT);
    }

    /// @notice Sets the AttestationValidator address
    /// @param _newValue New AttestationValidator address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(ATTESTATION_VALIDATOR_ADDRESS_SLOT, _newValue);
    }
}
