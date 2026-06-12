//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title PectraValidatorPubkeyLookup
/// @notice Unstructured-storage mapping of 0x02 pubkeys that have been initial-deposited
///         by River. Used by AttestationVerifier as a defense-in-depth check on top-ups:
///         entries in `batch.topUps` skip BLS verification, so the pubkey must already be
///         in this set or the call reverts. Without that gate, malicious root attesters
///         could classify an arbitrary attacker pubkey as a top-up and bypass BLS.
///
/// @dev    This set records membership only — not the operator that performed the initial
///         deposit. The `operatorIdx` field on a `TopUp` entry is therefore NOT verified
///         against any on-chain record: the root-attested buffer is the only attestation
///         we have for which operator a top-up credits.
library PectraValidatorPubkeyLookup {
    bytes32 internal constant PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.pectraValidatorPubkeyLookup")) - 1);

    /// @notice Check if a pubkey has been recorded.
    /// @param pubkey The raw 48-byte BLS pubkey.
    /// @return True if the pubkey was recorded.
    function isPubkeyFunded(bytes memory pubkey) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT, pubkey));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Record a pubkey as initial-deposited.
    /// @param pubkey The raw 48-byte BLS pubkey.
    function add(bytes memory pubkey) internal {
        bytes32 slot = keccak256(abi.encode(PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT, pubkey));
        LibUnstructuredStorage.setStorageBool(slot, true);
    }

    /// @notice Clear the entry for a pubkey.
    /// @param pubkey The raw 48-byte BLS pubkey.
    /// @return removed True if the pubkey was present and has been cleared; false if it
    ///         was already absent (in which case no SSTORE is performed).
    function remove(bytes memory pubkey) internal returns (bool removed) {
        bytes32 slot = keccak256(abi.encode(PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT, pubkey));
        if (!LibUnstructuredStorage.getStorageBool(slot)) {
            return false;
        }
        LibUnstructuredStorage.setStorageBool(slot, false);
        return true;
    }
}
