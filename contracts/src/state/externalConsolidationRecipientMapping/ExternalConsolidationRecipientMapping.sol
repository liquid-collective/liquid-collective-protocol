//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title External Consolidation Recipient Mapping Storage
/// @notice Utility to manage withdrawal-credential-address recipient mapping storage
library ExternalConsolidationRecipientMapping {
    /// @notice Storage slot of the withdrawal-credential-address recipient mapping
    bytes32 internal constant EXTERNAL_CONSOLIDATION_RECIPIENT_MAPPING_SLOT =
        bytes32(uint256(keccak256("river.state.externalConsolidationRecipientMapping")) - 1);

    /// @notice Structure stored in storage slot
    struct Slot {
        /// @custom:attribute Mapping from withdrawal credential addresses to recipient addresses
        mapping(address => address) value;
    }

    /// @notice Retrieve the recipient mapped to a withdrawal credential address
    /// @param _withdrawalCredentialAddress The withdrawal credential address to query
    /// @return The mapped recipient address
    function get(address _withdrawalCredentialAddress) internal view returns (address) {
        bytes32 slot = EXTERNAL_CONSOLIDATION_RECIPIENT_MAPPING_SLOT;

        Slot storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value[_withdrawalCredentialAddress];
    }

    /// @notice Set the recipient mapped to a withdrawal credential address
    /// @param _withdrawalCredentialAddress The withdrawal credential address to update
    /// @param _recipient The recipient address to set
    function set(address _withdrawalCredentialAddress, address _recipient) internal {
        bytes32 slot = EXTERNAL_CONSOLIDATION_RECIPIENT_MAPPING_SLOT;

        Slot storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value[_withdrawalCredentialAddress] = _recipient;
    }
}
