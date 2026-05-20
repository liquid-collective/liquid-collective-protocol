//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title ValidatorPubkeyLookup
/// @notice Unstructured storage library mapping each protocol-funded validator pubkey to
///         the operator that originally funded its initial deposit. Used by
///         AttestationVerifier as a defense-in-depth check on top-ups: a top-up entry
///         that flags `isTopUp=true` must reference a pubkey already recorded here,
///         AND the operator index attached to the top-up entry must match the one that
///         performed the initial deposit. Without that ownership bind, a compromised
///         deposit-committee quorum could mark a top-up against operator A's pubkey
///         while crediting `operator.funded` to operator B — silently desyncing
///         on-chain operator accounting from beacon-state stake.
///
///         Membership uses a slot-based mapping keyed by the raw 48-byte BLS pubkey:
///         slot = keccak256(abi.encode(VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT, pubkey))
///         The stored value is `operatorIdx + 1` (uint256), so the natural zero of
///         unset storage is the sentinel for "unknown / never funded", without needing
///         a separate exists-bit. `abi.encode` length-prefixes the dynamic `bytes` key
///         so distinct pubkeys cannot collide via length-extension.
library ValidatorPubkeyLookup {
    bytes32 internal constant VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.validatorPubkeyLookup.mapping")) - 1);

    /// @notice Retrieve the raw sentinel for a pubkey: 0 = unknown, n != 0 = funded by operator (n - 1).
    /// @dev Returns the sentinel as stored. Most callers should prefer `lookupValidatorPubkey`,
    ///      which decodes the sentinel into `(exists, operatorIdx)` and confines the `+1`/`-1`
    ///      arithmetic to this library.
    /// @param pubkey The raw 48-byte BLS pubkey.
    /// @return The stored sentinel (operatorIdx + 1), or 0 if never recorded.
    function getRawValidatorPubkeyEntry(bytes memory pubkey) internal view returns (uint256) {
        bytes32 slot = keccak256(abi.encode(VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT, pubkey));
        return LibUnstructuredStorage.getStorageUint256(slot);
    }

    /// @notice Decoded read of the funded-operator entry for a pubkey.
    /// @dev Encapsulates the `+1` sentinel scheme so callers never perform `stored - 1`
    ///      themselves — eliminating the underflow risk if the existence check is reordered.
    /// @param pubkey The raw 48-byte BLS pubkey.
    /// @return exists True if the pubkey was recorded.
    /// @return operatorIdx The operator that funded the initial deposit (defined iff exists).
    function lookupValidatorPubkey(bytes memory pubkey) internal view returns (bool exists, uint256 operatorIdx) {
        uint256 stored = getRawValidatorPubkeyEntry(pubkey);
        if (stored == 0) return (false, 0);
        return (true, stored - 1);
    }

    /// @notice Check if a pubkey has been recorded.
    /// @dev Convenience wrapper for callers that only need the "is this our pubkey?" predicate.
    ///      Top-up validation uses `lookupValidatorPubkey` to also bind the operator.
    /// @param pubkey The raw 48-byte BLS pubkey.
    /// @return True if the pubkey was recorded.
    function hasValidatorPubkey(bytes memory pubkey) internal view returns (bool) {
        return getRawValidatorPubkeyEntry(pubkey) != 0;
    }

    /// @notice Record a pubkey as funded by `operatorIdx`.
    /// @dev Stores `operatorIdx + 1` so the natural zero of unset storage doubles as
    ///      the "never funded" sentinel. Callers must guard against overwriting an
    ///      existing entry — re-funding a pubkey under a different operator would
    ///      silently rebind ownership, which is almost certainly a bug or attack.
    /// @param pubkey The raw 48-byte BLS pubkey.
    /// @param operatorIdx The operator index that funded the initial deposit.
    function addValidatorPubkey(bytes memory pubkey, uint256 operatorIdx) internal {
        bytes32 slot = keccak256(abi.encode(VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT, pubkey));
        LibUnstructuredStorage.setStorageUint256(slot, operatorIdx + 1);
    }

    /// @notice Clear the entry for a pubkey.
    /// @dev Plumbed for future EL-withdrawal code: when a validator exits and is no longer
    ///      controlled by the protocol, its pubkey must stop authorizing top-ups. Not invoked
    ///      from any external entry point in this version of the contract.
    /// @param pubkey The raw 48-byte BLS pubkey.
    function removeValidatorPubkey(bytes memory pubkey) internal {
        bytes32 slot = keccak256(abi.encode(VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT, pubkey));
        LibUnstructuredStorage.setStorageUint256(slot, 0);
    }
}
