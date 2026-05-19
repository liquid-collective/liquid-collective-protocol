//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title InitialDepositedPubkeys
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
///         Membership uses a slot-based mapping:
///         slot = keccak256(abi.encode(INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT, pubkeyHash))
///         where pubkeyHash = keccak256(48-byte BLS pubkey). The stored value is
///         `operatorIdx + 1` (uint256), so the natural zero of unset storage is the
///         sentinel for "unknown / never funded", without needing a separate exists-bit.
library InitialDepositedPubkeys {
    bytes32 internal constant INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.initialDepositedPubkeys.mapping")) - 1);

    /// @notice Retrieve the raw sentinel for a pubkey: 0 = unknown, n != 0 = funded by operator (n - 1).
    /// @param pubkeyHash The keccak256 hash of the 48-byte BLS pubkey.
    /// @return The stored sentinel (operatorIdx + 1), or 0 if never recorded.
    function getFundedOperator(bytes32 pubkeyHash) internal view returns (uint256) {
        bytes32 slot = keccak256(abi.encode(INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT, pubkeyHash));
        return LibUnstructuredStorage.getStorageUint256(slot);
    }

    /// @notice Check if a pubkey has been initial-deposited by River.
    /// @dev Convenience wrapper kept for back-compat with callers that only need the
    ///      "is this our pubkey?" predicate. New top-up validation uses
    ///      `getFundedOperator` directly to also bind the operator.
    /// @param pubkeyHash The keccak256 hash of the 48-byte BLS pubkey.
    /// @return True if the pubkey was recorded as initial-deposited.
    function hasInitialDeposit(bytes32 pubkeyHash) internal view returns (bool) {
        return getFundedOperator(pubkeyHash) != 0;
    }

    /// @notice Mark a pubkey as initial-deposited by `operatorIdx`.
    /// @dev Stores `operatorIdx + 1` so the natural zero of unset storage doubles as
    ///      the "never funded" sentinel. Callers must guard against overwriting an
    ///      existing entry — re-funding a pubkey under a different operator would
    ///      silently rebind ownership, which is almost certainly a bug or attack.
    /// @param pubkeyHash The keccak256 hash of the 48-byte BLS pubkey.
    /// @param operatorIdx The operator index that funded the initial deposit.
    function markInitialDeposited(bytes32 pubkeyHash, uint256 operatorIdx) internal {
        bytes32 slot = keccak256(abi.encode(INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT, pubkeyHash));
        LibUnstructuredStorage.setStorageUint256(slot, operatorIdx + 1);
    }

    /// @notice Clear the initial-deposit marker for a pubkey.
    /// @dev Plumbed for future EL-withdrawal code: when a validator exits and is no longer
    ///      controlled by the protocol, its pubkey must stop authorizing top-ups. Not invoked
    ///      from any external entry point in this version of the contract.
    /// @param pubkeyHash The keccak256 hash of the 48-byte BLS pubkey.
    function unmarkInitialDeposited(bytes32 pubkeyHash) internal {
        bytes32 slot = keccak256(abi.encode(INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT, pubkeyHash));
        LibUnstructuredStorage.setStorageUint256(slot, 0);
    }
}
