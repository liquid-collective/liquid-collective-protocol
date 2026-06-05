//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title PrePectraValidatorPubkeyLookup
/// @notice Unstructured-storage mapping of pre-Pectra pubkeys migrated from the legacy
///         operators-registry ValidatorKeys storage into AttestationVerifier state.
library PrePectraValidatorPubkeyLookup {
    bytes32 internal constant PRE_PECTRA_VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.prePectraValidatorPubkeyLookup.mapping")) - 1);

    /// @notice Check if a pre-Pectra pubkey has been migrated.
    /// @param pubkey The raw 48-byte BLS pubkey.
    /// @return True if the pubkey was migrated.
    function isPubkeyFunded(bytes memory pubkey) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(PRE_PECTRA_VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT, pubkey));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Record a pre-Pectra pubkey as funded.
    /// @param pubkey The raw 48-byte BLS pubkey.
    function add(bytes memory pubkey) internal {
        bytes32 slot = keccak256(abi.encode(PRE_PECTRA_VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT, pubkey));
        LibUnstructuredStorage.setStorageBool(slot, true);
    }

    /// @notice Clear the entry for a pubkey.
    /// @param pubkeys The raw 48-byte BLS pubkeys.
    function remove(bytes[] memory pubkeys) internal {
        for (uint256 i = 0; i < pubkeys.length; i++) {
            bytes memory pubkey = pubkeys[i];
            bytes32 slot = keccak256(abi.encode(PRE_PECTRA_VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT, pubkey));
            LibUnstructuredStorage.setStorageBool(slot, false);
        }
    }
}
