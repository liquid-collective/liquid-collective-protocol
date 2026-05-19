//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title InitialDepositedPubkeys
/// @notice Unstructured storage library for the set of validator pubkeys whose initial
///         deposit was successfully executed through River. Used by AttestationVerifier
///         as a defense-in-depth check on top-ups: a top-up entry that flags `isTopUp=true`
///         must reference a pubkey already present in this set, otherwise the call reverts.
///         Without this gate a compromised deposit-committee quorum could mark an attacker
///         pubkey as a top-up and bypass BLS verification.
///
///         Membership uses a slot-based mapping:
///         slot = keccak256(abi.encode(INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT, pubkeyHash))
///         where pubkeyHash = keccak256(48-byte BLS pubkey).
library InitialDepositedPubkeys {
    bytes32 internal constant INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.initialDepositedPubkeys.mapping")) - 1);

    /// @notice Check if a pubkey has been initial-deposited by River.
    /// @param pubkeyHash The keccak256 hash of the 48-byte BLS pubkey.
    /// @return True if the pubkey was recorded as initial-deposited.
    function hasInitialDeposit(bytes32 pubkeyHash) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT, pubkeyHash));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Mark a pubkey as initial-deposited.
    /// @param pubkeyHash The keccak256 hash of the 48-byte BLS pubkey.
    function markInitialDeposited(bytes32 pubkeyHash) internal {
        bytes32 slot = keccak256(abi.encode(INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT, pubkeyHash));
        LibUnstructuredStorage.setStorageBool(slot, true);
    }

    /// @notice Clear the initial-deposit marker for a pubkey.
    /// @dev Plumbed for future EL-withdrawal code: when a validator exits and is no longer
    ///      controlled by the protocol, its pubkey must stop authorizing top-ups. Not invoked
    ///      from any external entry point in this version of the contract.
    /// @param pubkeyHash The keccak256 hash of the 48-byte BLS pubkey.
    function unmarkInitialDeposited(bytes32 pubkeyHash) internal {
        bytes32 slot = keccak256(abi.encode(INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT, pubkeyHash));
        LibUnstructuredStorage.setStorageBool(slot, false);
    }
}
